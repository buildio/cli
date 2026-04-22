require "./spec_helper"
require "../src/env_format"

describe Build::EnvFormat do
  describe ".parse" do
    it "parses plain KEY=value" do
      Build::EnvFormat.parse("FOO=bar\n").should eq({"FOO" => "bar"})
    end

    it "parses single-quoted values literally" do
      Build::EnvFormat.parse("FOO='hello world'\n").should eq({"FOO" => "hello world"})
    end

    it "parses double-quoted values with \\n \\t \\r decoding" do
      Build::EnvFormat.parse(%(FOO="line1\\nline2\\ttab\\rcr"\n))
        .should eq({"FOO" => "line1\nline2\ttab\rcr"})
    end

    it "parses ANSI-C $'...' quoting" do
      Build::EnvFormat.parse(%(FOO=$'line1\\nline2'\n))
        .should eq({"FOO" => "line1\nline2"})
    end

    it "handles shell concatenation: 'it'\\''s' -> it's" do
      Build::EnvFormat.parse(%(FOO='it'\\''s'\n))
        .should eq({"FOO" => "it's"})
    end

    it "preserves embedded newlines inside single quotes (multi-line)" do
      Build::EnvFormat.parse("FOO='line1\nline2\nline3'\n")
        .should eq({"FOO" => "line1\nline2\nline3"})
    end

    it "strips 'export' prefix" do
      Build::EnvFormat.parse("export FOO=bar\n").should eq({"FOO" => "bar"})
    end

    it "ignores whole-line # comments" do
      Build::EnvFormat.parse("# comment\nFOO=bar\n").should eq({"FOO" => "bar"})
    end

    it "accepts bare values with hyphen, dot, underscore" do
      Build::EnvFormat.parse("FOO=a-b.c_d\n").should eq({"FOO" => "a-b.c_d"})
    end

    it "accepts an empty value" do
      Build::EnvFormat.parse("FOO=\n").should eq({"FOO" => ""})
    end

    it "keeps embedded '=' inside quoted values" do
      Build::EnvFormat.parse("FOO='a=b=c'\n").should eq({"FOO" => "a=b=c"})
    end

    it "parses the heroku-style PEM export format" do
      raw = %(KEY="-----BEGIN RSA PRIVATE KEY-----\\nMIIE\\n-----END RSA PRIVATE KEY-----\\n"\n)
      Build::EnvFormat.parse(raw)
        .should eq({"KEY" => "-----BEGIN RSA PRIVATE KEY-----\nMIIE\n-----END RSA PRIVATE KEY-----\n"})
    end

    it "parses several assignments in one stream" do
      Build::EnvFormat.parse("A=1\nB=2\nC='three'\n")
        .should eq({"A" => "1", "B" => "2", "C" => "three"})
    end

    describe "SECURITY: never expands or executes" do
      it "does NOT expand $VAR inside double quotes" do
        Build::EnvFormat.parse(%(FOO="$HOME"\n))
          .should eq({"FOO" => "$HOME"})
      end

      it "does NOT expand $(cmd) inside double quotes" do
        Build::EnvFormat.parse(%(FOO="$(whoami)"\n))
          .should eq({"FOO" => "$(whoami)"})
      end

      it "does NOT expand backticks inside double quotes" do
        Build::EnvFormat.parse(%(FOO="`whoami`"\n))
          .should eq({"FOO" => "`whoami`"})
      end

      it "does NOT expand $VAR in bare values" do
        Build::EnvFormat.parse("FOO=$HOME\n").should eq({"FOO" => "$HOME"})
      end

      it "does NOT perform glob expansion" do
        Build::EnvFormat.parse("FOO=*.txt\n").should eq({"FOO" => "*.txt"})
      end

      it "does NOT execute when values contain shell metacharacters" do
        Build::EnvFormat.parse("FOO='; rm -rf /; echo '\n")
          .should eq({"FOO" => "; rm -rf /; echo "})
      end
    end
  end

  describe ".shell_format_kv" do
    it "emits bare form for simple identifiers" do
      Build::EnvFormat.shell_format_kv("FOO", "bar").should eq("FOO=bar")
    end

    it "single-quotes values with spaces" do
      Build::EnvFormat.shell_format_kv("FOO", "hello world")
        .should eq("FOO='hello world'")
    end

    it "escapes embedded single quotes via close-escape-reopen" do
      Build::EnvFormat.shell_format_kv("FOO", "it's")
        .should eq(%(FOO='it'\\''s'))
    end

    it "uses $'...' for values with newlines" do
      Build::EnvFormat.shell_format_kv("FOO", "a\nb").should eq(%(FOO=$'a\\nb'))
    end

    it "uses $'...' for values with tabs and CR" do
      Build::EnvFormat.shell_format_kv("FOO", "a\tb\rc")
        .should eq(%(FOO=$'a\\tb\\rc'))
    end
  end

  describe "round-trip" do
    it "preserves every shape through parse -> emit -> parse" do
      cases = {
        "simple"      => "bar",
        "spaces"      => "hello world",
        "apostrophe"  => "it's me",
        "newlines"    => "line1\nline2\nline3",
        "pem"         => "-----BEGIN KEY-----\nMIIE\n-----END KEY-----\n",
        "tabs"        => "col1\tcol2",
        "dollars"     => "price: $100 (literal)",
        "shell_meta"  => "a; b && c | d > e",
        "empty"       => "",
      }

      cases.each do |_label, value|
        emitted = Build::EnvFormat.shell_format_kv("FOO", value) + "\n"
        Build::EnvFormat.parse(emitted).should eq({"FOO" => value})
      end
    end
  end
end
