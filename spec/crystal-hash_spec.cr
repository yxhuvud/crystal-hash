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

  # it "many entries" do
  #   hsh = Hash(Int32, Int32).new(nil)
  #   (1..100_000_000).each do |i|
  #     hsh[i] = i
  #   end

  #   (1..100_000_000).each do |i|
  #     hsh[i].should eq i
  #   end
  # end

  it "many hashes" do
    times = 100_00000
    arr = Array(Hash2b(Int32, Int32)).new(times)

    size = 10
    0.upto(times) do
      hsh = Hashb(Int32, Int32).new nil, size
      arr << hsh
      size.times do |i|
        hsh[i] = i
      end
    end
    valid = true
    0.upto(times) do |l|
      size.times do |i|
        valid &&= (arr[l][i] == i)
      end
    end
    valid.should be_true
  end

  it "deletes" do
    hsh = Hash2b(Int32, Int32).new
    hsh[1] = 42
    hsh.size.should eq 1

    hsh.delete(5).should be_nil
    hsh.size.should eq 1

    hsh.delete(1).should eq 42
    expect_raises do
      hsh[1]
    end
    hsh[1]?.should be_nil
    hsh.size.should eq 0

    hsh.delete(1).should eq nil
    hsh.size.should eq 0
  end

  # it "deletes en masse" do
  #   hsh = Hash2b(Int32, Int32).new(nil)
  #   (1..10_000_000).each do |i|
  #     hsh[i] = i
  #   end

  #   (1..10_000_000).each do |i|
  #     hsh.delete(i).should eq i
  #   end

  #   (1..10_000_000).each do |i|
  #     hsh[2*i] = i
  #   end

  #   (1..10_000_000).each do |i|
  #     hsh.delete(2*i).should eq i
  #   end
  # end
end
