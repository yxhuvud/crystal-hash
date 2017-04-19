require "./spec_helper"

describe Crystal::Hash do
  it "empty" do
    hsh = Hash2b(String, Int32).new
    hsh.size.should eq 0
    expect_raises do
      hsh["kalle"]
    end
    hsh["kalle"]?.should be_nil
  end

  it "insert 1 element" do
    hsh = Hash2b(String, Int32).new
    hsh["kalle"] = 2
    hsh.size.should eq 1
    hsh["kalle"].should eq 2
    hsh["kalle2"]?.should eq nil
  end

  it "insert 1 element twice" do
    hsh = Hash2b(String, Int32).new
    hsh["kalle"] = 2
    hsh["kalle"] = 2
    hsh["kalle"] = 3
    hsh.size.should eq 1
    hsh["kalle"].should eq 3
  end

  it "insert 2 elements" do
    hsh = Hash2b(String, Int32).new
    hsh["kalle"] = 2
    hsh["kula"] = 3

    hsh.size.should eq 2
    hsh["kalle"].should eq 2
    hsh["kula"].should eq 3
    hsh["kalle2"]?.should eq nil
  end

  it "insert 26 elements" do
    hsh = Hash2b(Char, Int32).new
    range = 'a'..'z'
    range.each.with_index do |c, i|
      hsh[c] = i
    end

    hsh.size.should eq 26
    range.each.with_index do |c, i|
      hsh[c].should eq i
    end

    range.each.with_index do |c, i|
      hsh[c] = i * 2
    end

    range.each.with_index do |c, i|
      hsh[c].should eq i * 2
    end
  end
end
