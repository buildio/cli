module Build
  # Parse and emit shell-style KEY=VALUE environment assignments.
  #
  # Accepts the subset of POSIX sh assignment syntax used by
  # `bld config -s`, `heroku config -s`, `export -p`, and common
  # .env files:
  #
  #   [export] IDENT=<value>
  #   value := '...'                 literal
  #          | "..."                 with \n \t \r \\ \" \$ \` escapes
  #          | $'...'                ANSI-C: \n \t \r \\ \' \" \0 \a \b \e \f \v
  #          | bare                  unquoted, no expansion
  #
  # Values may concatenate quoted and unquoted segments like real shell:
  # `'it'\''s'` parses as `it's`, matching what our emitter produces for
  # a value containing a single quote. Quoted segments can span newlines.
  #
  # SECURITY: this is deliberately NOT a shell. It never performs variable
  # expansion, command substitution, arithmetic, globbing, or any other
  # form of evaluation. The worst an attacker can do with crafted input is
  # set config var values to arbitrary bytes — which any user can already
  # do via explicit KEY=VALUE args. That invariant keeps the attack
  # surface of piping a file identical to passing args explicitly.
  module EnvFormat
    # Ref wrapper so we can pass the reader by reference to helpers
    # (Char::Reader is a struct; mutations to a copy don't propagate).
    private class Cursor
      @r : Char::Reader
      def initialize(s : String); @r = Char::Reader.new(s); end
      def has_next? : Bool; @r.has_next?; end
      def current_char : Char; @r.current_char; end
      def next_char : Nil; @r.next_char; nil; end
      def pos : Int32; @r.pos; end
      def rest : String; @r.string.byte_slice(@r.pos); end
    end

    # Parse assignments out of a raw string. Lines that don't match the
    # grammar (malformed, stray text, etc.) are silently skipped to stay
    # tolerant of format drift between producers.
    def self.parse(raw : String) : Hash(String, String)
      result = Hash(String, String).new
      c = Cursor.new(raw)

      while c.has_next?
        skip_blank_and_ws(c)
        break unless c.has_next?

        if c.current_char == '#'
          skip_to_eol(c)
          next
        end

        if c.rest.starts_with?("export ") || c.rest.starts_with?("export\t")
          6.times { c.next_char }
          while c.has_next? && (c.current_char == ' ' || c.current_char == '\t')
            c.next_char
          end
        end

        key = read_key(c)
        if key.empty? || !c.has_next? || c.current_char != '='
          skip_to_eol(c)
          next
        end
        c.next_char # consume '='

        result[key] = read_value(c)
        skip_to_eol(c)
      end

      result
    end

    # Emit one KEY=value line that round-trips through `parse` above,
    # `bash source`, and `heroku config -s`-style consumers. Values with
    # control characters use $'...' (ANSI-C) so they stay single-line
    # and decode back to the same bytes.
    def self.shell_format_kv(key : String, value : String) : String
      if value.matches?(/\A[0-9a-zA-Z_\-\.]+\z/)
        "#{key}=#{value}"
      elsif value.matches?(/[\x00-\x1f\x7f]/)
        escaped = value.gsub('\\', "\\\\")
                       .gsub('\'', "\\'")
                       .gsub('\n', "\\n")
                       .gsub('\t', "\\t")
                       .gsub('\r', "\\r")
        escaped = escaped.gsub(/[\x00-\x1f\x7f]/) { |ch| "\\x%02x" % ch.bytes[0] }
        "#{key}=$'#{escaped}'"
      else
        "#{key}='#{value.gsub("'", "'\\''")}'"
      end
    end

    # ---- internals ----

    private def self.skip_blank_and_ws(c : Cursor) : Nil
      while c.has_next?
        ch = c.current_char
        break unless ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
        c.next_char
      end
    end

    private def self.skip_to_eol(c : Cursor) : Nil
      while c.has_next? && c.current_char != '\n'
        c.next_char
      end
      c.next_char if c.has_next?
    end

    private def self.read_key(c : Cursor) : String
      String.build do |sb|
        ch = c.has_next? ? c.current_char : '\0'
        if ch.ascii_letter? || ch == '_'
          sb << ch
          c.next_char
          while c.has_next? && (c.current_char.ascii_alphanumeric? || c.current_char == '_')
            sb << c.current_char
            c.next_char
          end
        end
      end
    end

    # Consume a value up to unquoted whitespace or EOL. Supports shell's
    # implicit segment concatenation; quoted segments can span newlines.
    private def self.read_value(c : Cursor) : String
      String.build do |sb|
        loop do
          break unless c.has_next?
          ch = c.current_char
          break if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'

          case ch
          when '\''
            c.next_char
            while c.has_next? && c.current_char != '\''
              sb << c.current_char
              c.next_char
            end
            c.next_char if c.has_next?
          when '"'
            c.next_char
            while c.has_next? && c.current_char != '"'
              if c.current_char == '\\'
                c.next_char
                break unless c.has_next?
                case c.current_char
                when 'n'  then sb << '\n'
                when 't'  then sb << '\t'
                when 'r'  then sb << '\r'
                when '\\' then sb << '\\'
                when '"'  then sb << '"'
                when '$'  then sb << '$'
                when '`'  then sb << '`'
                else           sb << '\\' << c.current_char
                end
                c.next_char
              else
                sb << c.current_char
                c.next_char
              end
            end
            c.next_char if c.has_next?
          when '$'
            if c.rest.starts_with?("$'")
              c.next_char
              c.next_char
              while c.has_next? && c.current_char != '\''
                if c.current_char == '\\'
                  c.next_char
                  break unless c.has_next?
                  case c.current_char
                  when 'n'  then sb << '\n'
                  when 't'  then sb << '\t'
                  when 'r'  then sb << '\r'
                  when '\\' then sb << '\\'
                  when '\'' then sb << '\''
                  when '"'  then sb << '"'
                  when '0'  then sb << '\0'
                  when 'a'  then sb << '\a'
                  when 'b'  then sb << '\b'
                  when 'e'  then sb << '\e'
                  when 'f'  then sb << '\f'
                  when 'v'  then sb << '\v'
                  else           sb << c.current_char
                  end
                  c.next_char
                else
                  sb << c.current_char
                  c.next_char
                end
              end
              c.next_char if c.has_next?
            else
              # Bare $ — do NOT expand. Literal dollar sign.
              sb << '$'
              c.next_char
            end
          when '\\'
            c.next_char
            if c.has_next?
              sb << c.current_char
              c.next_char
            end
          else
            sb << ch
            c.next_char
          end
        end
      end
    end
  end
end
