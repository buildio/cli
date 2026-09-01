require "./spec_helper"
require "../src/display_width"

describe Build do
  describe ".display_width" do
    it "counts CJK codepoints as full-width cells" do
      cjk = "\u{540D}\u{524D}"
      Build.display_width(cjk).should eq(4)
      Build.display_width("name").should eq(4)
    end

    it "ignores ANSI escapes and Athena markup" do
      cjk = "\u{540D}\u{524D}"
      Build.display_width("\e[31m#{cjk}\e[0m").should eq(4)
      Build.display_width("<info>#{cjk}</info>").should eq(4)
    end
  end

  describe ".ljust_display" do
    it "pads by display cells instead of codepoint count" do
      cjk = "\u{540D}\u{524D}"
      Build.ljust_display(cjk, 6).should eq("#{cjk}  ")
    end
  end
end
