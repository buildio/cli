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
# This should take an argument abbreviate as a boolean with default of true:
def distance_of_time_in_words(time_ago, abbreviate = true)
  elapsed_time = (Time.utc - time_ago).total_seconds.to_i.seconds
  days_ago = (elapsed_time.total_seconds / 86400).to_i
  hours_ago = ((elapsed_time.total_seconds % 86400) / 3600).to_i
  minutes_ago = ((elapsed_time.total_seconds % 3600) / 60).to_i
  seconds_ago = (elapsed_time.total_seconds % 60).to_i

  dotiw = [] of String
  dotiw << "#{days_ago}d " if days_ago > 0
  dotiw << "#{hours_ago}h " if hours_ago > 0 || days_ago > 0
  dotiw << "#{minutes_ago}m " if minutes_ago > 0 || hours_ago > 0 || days_ago > 0
  dotiw << "#{seconds_ago}s" if seconds_ago > 0 || minutes_ago > 0 || hours_ago > 0 || days_ago > 0
  dotiw << "0s" if dotiw.empty?
  if abbreviate
    return dotiw.first.strip
  else
    return dotiw.join
  end
end
