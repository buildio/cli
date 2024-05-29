def prompt_any_key(prompt : String) : Char
  mark = "?".colorize(:light_blue)
  print "#{mark} #{prompt} "
  char = STDIN.raw &.read_char
  puts char
  char || 'q'
end
def launch_browser(url)
  {% if flag?(:darwin) %}
    Process.run("open #{url}", shell: true)
  {% elsif flag?(:win32) %}
    Process.run("start #{url}", shell: true)
  {% elsif flag?(:unix) %}
    Process.run("xdg-open #{url}", shell: true)
  {% end %}
end
def dots_spinner(status = nil)
  frames = %w{⠙ ⠹ ⠸ ⠼ ⠴}
  cyan    = frames.map { |frame| frame.colorize(:cyan).to_s }
  frames = %w{⠦ ⠧ ⠇ ⠏ ⠋}
  magenta = frames.map { |frame| frame.colorize(:magenta).to_s }
  frames  = cyan + magenta
  spinner = Term::Spinner.new(":spinner :status", frames: frames, format: :dots, success_mark: "✓".colorize(:green).to_s, error_mark: "✗".colorize(:red).to_s)
  spinner.update(status: status) if status
  spinner.auto_spin
  spinner
end
