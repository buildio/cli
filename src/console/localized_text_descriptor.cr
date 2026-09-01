require "athena-console"
require "../display_width"
require "../i18n"

module Build
  module Console
    def self.default_input_definition(default_command = "list") : ACON::Input::Definition
      ACON::Input::Definition.new(
        ACON::Input::Argument.new("command", :required, Build.t("console.global.command")),
        ACON::Input::Option.new("help", "h", description: Build.t("console.global.help", command: default_command)),
        ACON::Input::Option.new("quiet", "q", description: Build.t("console.global.quiet")),
        ACON::Input::Option.new("verbose", "v|vv|vvv", description: Build.t("console.global.verbose")),
        ACON::Input::Option.new("version", "V", description: Build.t("console.global.version")),
        ACON::Input::Option.new("ansi", value_mode: :negatable, description: Build.t("console.global.ansi"), default: false),
        ACON::Input::Option.new("no-interaction", "n", description: Build.t("console.global.no_interaction")),
      )
    end

    class LocalizedTextDescriptor < ACON::Descriptor
      protected def describe(application : ACON::Application, context : ACON::Descriptor::Context) : Nil
        described_namespace = context.namespace
        description = ACON::Descriptor::Application.new application, context.namespace

        commands = description.commands.values

        if context.raw_text?
          width = self.width commands

          commands.each do |command|
            self.write_text sprintf("%-#{width}s %s", command.name, command.description), context
            self.write_text "\n"
          end

          return
        end

        self.write_text "#{application.help}\n\n", context

        self.write_text "<comment>#{label("usage")}</comment>\n", context
        self.write_text "  #{label("command_usage")}\n\n", context

        self.describe ACON::Input::Definition.new(application.definition.options), context

        self.write_text "\n"
        self.write_text "\n"

        commands = description.commands
        namespaces = description.namespaces

        if described_namespace && !namespaces.empty?
          namespaces.values.first[:commands].each do |n|
            commands[n] = description.command n
          end
        end

        width = self.width(
          namespaces.values.flat_map do |n|
            commands.keys & n[:commands]
          end.uniq!
        )

        if described_namespace
          self.write_text %(<comment>#{Build.t("console.descriptor.available_namespace_commands", namespace: described_namespace)}</comment>), context
        else
          self.write_text "<comment>#{label("available_commands")}</comment>", context
        end

        namespaces.each_value do |namespace|
          namespace[:commands].select! { |c| commands.has_key? c }

          next if namespace[:commands].empty?

          if !described_namespace && namespace[:id] != ACON::Descriptor::Application::GLOBAL_NAMESPACE
            self.write_text "\n"
            self.write_text " <comment>#{namespace[:id]}</comment>", context
          end

          namespace[:commands].each do |name|
            self.write_text "\n"
            spacing_width = width - Build.display_width(name)
            command = commands[name]
            command_aliases = name === command.name ? self.command_aliases_text command : ""

            self.write_text "  <info>#{name}</info>#{" " * spacing_width}#{command_aliases}#{command.description}", context
          end
        end

        self.write_text "\n"
      end

      protected def describe(argument : ACON::Input::Argument, context : ACON::Descriptor::Context) : Nil
        default = if !argument.default.nil? && !argument.default.is_a?(Array)
                    %(<comment> #{Build.t("console.descriptor.default", value: self.format_default_value(argument.default))}</comment>)
                  else
                    ""
                  end

        total_width = context.total_width || Build.display_width(argument.name)
        spacing_width = total_width - Build.display_width(argument.name)

        self.write_text(
          sprintf(
            "  <info>%s</info>  %s%s%s",
            argument.name,
            " " * spacing_width,
            argument.description.gsub(/\s*[\r\n]\s*/, "\n#{" " * (total_width + 4)}"),
            default
          ),
          context
        )
      end

      protected def describe(command : ACON::Command, context : ACON::Descriptor::Context) : Nil
        command.merge_application_definition false

        if description = command.description.presence
          self.write_text "<comment>#{label("description")}</comment>", context
          self.write_text "\n"
          self.write_text "  #{description}"
          self.write_text "\n\n"
        end

        self.write_text "<comment>#{label("usage")}</comment>", context

        ([command.synopsis(true)] + command.aliases + command.usages).each do |usage|
          self.write_text "\n"
          self.write_text "  #{ACON::Formatter::Output.escape usage}", context
        end

        self.write_text "\n"

        definition = command.definition

        if !definition.options.empty? || !definition.arguments.empty?
          self.write_text "\n"
          self.describe definition, context
          self.write_text "\n"
        end

        if (help = command.processed_help).presence && help != description
          self.write_text "\n"
          self.write_text "<comment>#{label("help")}</comment>", context
          self.write_text "\n"
          self.write_text "  #{help.gsub("\n", "\n  ")}", context
          self.write_text "\n"
        end
      end

      protected def describe(definition : ACON::Input::Definition, context : ACON::Descriptor::Context) : Nil
        total_width = self.calculate_total_width_for_options definition.options

        definition.arguments.each_value do |arg|
          total_width = Math.max total_width, Build.display_width(arg.name)
        end

        unless definition.arguments.empty?
          self.write_text "<comment>#{label("arguments")}</comment>", context
          self.write_text "\n"

          new_context = context.clone
          new_context.total_width = total_width

          definition.arguments.each_value do |arg|
            self.describe arg, new_context
            self.write_text "\n"
          end
        end

        if !definition.arguments.empty? && !definition.options.empty?
          self.write_text "\n"
        end

        unless definition.options.empty?
          later_options = [] of ACON::Input::Option

          self.write_text "<comment>#{label("options")}</comment>", context

          definition.options.each_value do |option|
            if (option.shortcut || "").size > 1
              later_options << option
              next
            end

            new_context = context.clone
            new_context.total_width = total_width

            self.write_text "\n"
            self.describe option, new_context
          end

          later_options.each do |option|
            self.write_text "\n"

            new_context = context.clone
            new_context.total_width = total_width

            self.describe option, new_context
          end
        end
      end

      protected def describe(option : ACON::Input::Option, context : ACON::Descriptor::Context) : Nil
        if option.accepts_value? && !option.default.nil? && (!option.default.is_a?(Array) || !option.default.as(Array).empty?)
          default = %(<comment> #{Build.t("console.descriptor.default", value: self.format_default_value(option.default))}</comment>)
        else
          default = ""
        end

        value = ""
        if option.accepts_value?
          value = "=#{option.name.upcase}"

          if option.value_optional?
            value = "[#{value}]"
          end
        end

        total_width = context.total_width || self.calculate_total_width_for_options [option]
        synopsis = sprintf(
          "%s%s",
          (s = option.shortcut) ? sprintf("-%s, ", s) : "    ",
          (option.negatable? ? "--%<name>s|--no-%<name>s" : "--%<name>s%<value>s") % {name: option.name, value: value}
        )

        spacing_width = total_width - Build.display_width(synopsis)

        self.write_text(
          sprintf(
            "  <info>%s</info>  %s%s%s%s",
            synopsis,
            " " * spacing_width,
            option.description.gsub(/\s*[\r\n]\s*/, "\n#{" " * (total_width + 4)}"),
            default,
            option.is_array? ? "<comment> #{label("multiple_values_allowed")}</comment>" : ""
          ),
          context
        )
      end

      private def label(key : String) : String
        Build.t("console.descriptor.#{key}")
      end

      private def calculate_total_width_for_options(options : Hash(String, ACON::Input::Option)) : Int32
        self.calculate_total_width_for_options options.values
      end

      private def calculate_total_width_for_options(options : Array(ACON::Input::Option)) : Int32
        return 0 if options.empty?

        options.max_of do |o|
          name_length = 1 + Math.max(Build.display_width(o.shortcut || ""), 1) + 4 + Build.display_width(o.name)

          if o.negatable?
            name_length += 6 + Build.display_width(o.name)
          elsif o.accepts_value?
            name_length += 1 + Build.display_width(o.name) + (o.value_optional? ? 2 : 0)
          end

          name_length
        end
      end

      private def command_aliases_text(command : ACON::Command) : String
        String.build do |io|
          unless (aliases = command.aliases).empty?
            io << '['
            aliases.join io, '|'
            io << ']' << ' '
          end
        end
      end

      private def format_default_value(default)
        case default
        when String
          %("#{ACON::Formatter::Output.escape default}")
        when Enumerable
          %([#{default.map { |item| %|"#{ACON::Formatter::Output.escape item.to_s}"| }.join ","}])
        else
          default
        end
      end

      private def width(commands : Array(ACON::Command) | Array(String)) : Int32
        widths = Array(Int32).new

        commands.each do |command|
          case command
          in ACON::Command
            widths << Build.display_width command.name.not_nil!

            command.aliases.each do |a|
              widths << Build.display_width a
            end
          in String
            widths << Build.display_width command
          end
        end

        widths.empty? ? 0 : widths.max + 2
      end

      private def write_text(content : String, context : ACON::Descriptor::Context? = nil) : Nil
        unless ctx = context
          return self.write content, true
        end

        raw_output = true

        ctx.raw_output?.try do |ro|
          raw_output = !ro
        end

        if ctx.raw_text?
          content = content.gsub(/(?:<\/?[^>]*>)|(?:<!--(.*?)-->[\n]?)/, "")
        end

        self.write(
          content,
          raw_output
        )
      end
    end
  end
end
