module Build
  ANSI_ESCAPE = /\e\[[0-?]*[ -\/]*[@-~]/
  ACON_MARKUP = /<\/?[^>]*>/

  def self.display_width(value : String) : Int32
    value.gsub(ANSI_ESCAPE, "").gsub(ACON_MARKUP, "").each_char.sum { |char| char_display_width(char) }
  end

  def self.ljust_display(value : String, width : Int32) : String
    padding = width - display_width(value)
    padding > 0 ? value + (" " * padding) : value
  end

  def self.char_display_width(char : Char) : Int32
    codepoint = char.ord
    return 0 if codepoint < 0x20 || (0x7f <= codepoint <= 0x9f)
    return 0 if combining_mark?(codepoint)
    fullwidth?(codepoint) ? 2 : 1
  end

  private def self.combining_mark?(codepoint : Int32) : Bool
    (0x0300 <= codepoint <= 0x036f) ||
      (0x1ab0 <= codepoint <= 0x1aff) ||
      (0x1dc0 <= codepoint <= 0x1dff) ||
      (0x20d0 <= codepoint <= 0x20ff) ||
      (0xfe20 <= codepoint <= 0xfe2f)
  end

  private def self.fullwidth?(codepoint : Int32) : Bool
    (0x1100 <= codepoint <= 0x115f) ||
      codepoint == 0x2329 ||
      codepoint == 0x232a ||
      (0x2e80 <= codepoint <= 0xa4cf && codepoint != 0x303f) ||
      (0xac00 <= codepoint <= 0xd7a3) ||
      (0xf900 <= codepoint <= 0xfaff) ||
      (0xfe10 <= codepoint <= 0xfe19) ||
      (0xfe30 <= codepoint <= 0xfe6f) ||
      (0xff00 <= codepoint <= 0xff60) ||
      (0xffe0 <= codepoint <= 0xffe6)
  end
end
