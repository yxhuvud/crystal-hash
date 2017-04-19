class Hash2b(K, V)
  # include Enumerable({K, V})
  # include Iterable({K, V})

  getter size : Int32
  getter first : Int32?
  getter last : Int32?

  # protected getter entries
  # protected getter bins
  # protected getter entry_power
  # protected getter bin_power
  # protected getter rebuilds
  property entries : Entries(K, V)
  getter bins : Bins(K, V) | Nil
  getter entry_power : UInt16
  getter bin_power : UInt8
  getter rebuilds : Int32

  record(Entry(K, V), hash : Int32, key : K, value : V) do
    def eq?(o_key : K, o_hash : Int32)
      hash == o_hash && key == o_key
    end
  end

  struct Bins(K, V)
    EMPTY     = 0
    DELETED   = 1
    BASE      = 2
    UNDEFINED = ~0

    property bins : Slice(Int32)

    def initialize(size)
      @bins = Slice(Int32).new(size, EMPTY)
    end

    def empty?(i : Int32)
      bins[i] == EMPTY
    end

    def deleted?(i : Int32)
      bins[i] == DELETED
    end

    def empty_or_deleted?(i : Int32)
      bins[i] <= DELETED
    end

    def mark_deleted(i : Int32)
      assert i != UNDEFINED
      assert !empty_or_deleted?(i)
      set_bin(i, DELETED, 0)
    end

    def mark_empty(i : Int32)
      set_bin(i, EMPTY, 0)
    end

    # TODO: ruby version uses variable index sizes depending on size
    # of bin table. Should that be done here as well?
    def set_bin(n, v, offset = BASE)
      bins[n] = v + offset
    end

    def get_bin(n, offset = BASE)
      bins[n] - offset
    end

    def bin_count
      bins.size
    end

    def mask
      bin_count - 1
    end

    def bin_hash(hash)
      hash & mask
    end

    def clear
      @bins.each_with_index do |_, i|
        @bins[i] = EMPTY
      end
    end

    # Find index of bin and entry for key and hash. If there is no such bin,
    # return {Bin::UNDEFINED, Entries::UNDEFINED}
    def index(key : K, hash : Int32, entries : Entries(K, V))
      index = bin_hash(hash)
      perturb = hash
      loop do
        if !empty_or_deleted?(index)
          entry_index = get_bin(index)
          entry = entries[entry_index]
          return {bin: index, entries: entry_index} if entry.eq?(key, hash)
        elsif empty?(index)
          return {bin: Bins::UNDEFINED, entries: Entries::UNDEFINED}
        end
        index, perturb = secondary_hash(index, perturb)
      end
    end

    # Finds the next unused index for key.
    def unused_index(key : K, hash : Int32, entries : Entries)
      index = bin_hash(hash)
      if entries.allocated_size > bins.size
        raise "bins too small!"
      end
      perturb = hash
      until empty_or_deleted?(index)
        index, perturb = secondary_hash(index, perturb)
      end
      index
    end

    # Return index for HASH and KEY in bin and entry tables. Reserve
    # the bin for inclusion of the corresponding entry into the table
    # if it is not there yet. We always find such bin as bins array
    # length is bigger entries array. Although we can reuse a deleted
    # bin, the result bin value is always empty if the table has no
    # entry with KEY. Return the entries array index of the found
    # entry or Entries::UNDEFINED if it is not found.
    def reserve_index(key : K, hash : Int32, entries : Entries)
      index = bin_hash(hash)
      perturb = hash
      first_deleted = UNDEFINED
      loop do
        entry_index = get_bin(index)
        if empty?(index)
          entry_index = Entries::UNDEFINED
          if first_deleted != UNDEFINED
            # we can reuse a deleted index
            index = first_deleted
            mark_empty(index)
          end
          return {entry_index, index}
        elsif !deleted?(index)
          if entries[entry_index].eq?(key, hash)
            return {entry_index, index}
          end
        elsif first_deleted == UNDEFINED
          first_deleted = index
        end
        index, perturb = secondary_hash(index, perturb)
      end
    end

    def insert!(entry, index, new_entries)
      bin_index = unused_index(entry.key, entry.hash, new_entries)
      raise "Invalid bin_index" unless bin_index != Bins::UNDEFINED && empty?(bin_index)
      set_bin(bin_index, index)
    end

    # Return the next secondary hash index for table TAB using previous
    #  index INDEX and PERTURB.  Finally modulo of the function becomes a
    #  full *cycle linear congruential generator*, in other words it
    #  guarantees traversing all table bins in extreme case.
    #  According the Hull-Dobell theorem a generator
    #  "Xnext = (a*Xprev + c) mod m" is a full cycle generator iff
    #    o m and c are relatively prime
    #    o a-1 is divisible by all prime factors of m
    #    o a-1 is divisible by 4 if m is divisible by 4.
    #  For our case a is 5, c is 1, and m is a power of two.
    private def secondary_hash(index, perturb)
      perturb >>= 11
      index = (index << 2) + index + perturb + 1
      {bin_hash(index), perturb}
    end
  end

  struct Entries(K, V)
    property entries : Slice(Entry(K, V))
    property starts_at
    property stops_at

    UNDEFINED = ~0

    def initialize(size)
      key = uninitialized K
      value = uninitialized V
      hash = UNDEFINED
      entry = Entry.new(hash, key, value)

      @entries = Slice(Entry(K, V)).new(size, entry)
      @starts_at = 0
      @stops_at = 0
    end

    def initialize(@entries : Slice(Entry(K, V)), @starts_at, @stops_at)
    end

    def mark_deleted(i)
      entries[i].hash = RESERVED_HASH_VALUE
    end

    def deleted?(i)
      entries[i].hash == RESERVED_HASH_VALUE
    end

    def clear
      @starts_at = @stops_at = 0
    end

    # linear search, used for small tables.
    def index(hash, key)
      starts_at.upto(stops_at - 1) do |i|
        return i if entries[i].eq?(hash, key)
      end
      UNDEFINED
    end

    def each_with_index
      starts_at.upto(stops_at) do |i|
        val = {entries[i], i}
        unless deleted?(i)
          yield val
        end
      end
    end

    def [](i)
      entries[i]
    end

    def []=(i, entry : Entry)
      entries[i] = entry
    end

    def copy_to(other_or_self)
      new_index = 0
      starts_at.upto(stops_at - 1) do |i|
        next if deleted?(i)
        other_or_self[new_index] = entries[i]
        new_index += 1
      end
      other_or_self.starts_at = 0
      other_or_self.stops_at = new_index
      other_or_self
    end

    def allocated_size
      entries.size
    end
  end

  def initialize(block : (Hash(K, V), K -> V)? = nil, initial_capacity = 0)
    @size = 0
    @rebuilds = 0
    @entry_power = power2(initial_capacity)
    @bin_power = feature.bin_power
    if @entry_power <= MAX_POWER2_FOR_TABLES_WITHOUT_BINS
      @bins = nil
    else
      @bins = Bins(K, V).new(feature.bin_words)
    end

    @entries = Entries(K, V).new(allocated_entries)
  end

  private def lookup(key : K)
    hash = do_hash(key)
    index = if (bins = @bins)
              bins.index(key, hash, entries)[:entries]
            else
              entries.index(key, hash)
            end
    found = index != Entries::UNDEFINED
    entry = found ? entries[index] : nil
    {found, entry && entry.value}
  end

  private def make_empty
    @size = 0
    @entries.clear
    @bins.clear if @bins
  end

  def clear
    make_empty
    @rebuilds += 1
    # Check?
  end

  def rehash
    puts "rebuilding at size #{@size}"
    if ((2 * size <= allocated_entries &&
       REBUILD_THRESHOLD * size > allocated_entries) ||
       size < (1 << MINIMAL_POWER2))
      # compaction
      bins = @bins
      bins.clear if bins
      new_tab = self
    else
      new_tab = self.class.new(nil, 2 * size - 1)
    end
    bins = new_tab.bins
    new_tab.entries = entries.copy_to(new_tab.entries)
    if bins
      new_tab.entries.each_with_index do |entry, index|
        bins.insert!(entry, index, new_tab.entries)
      end
    end

    if new_tab != self
      @entry_power = new_tab.entry_power
      @bin_power = new_tab.bin_power
      @bins = new_tab.bins
      @entries = new_tab.entries
    end
    raise "invalid size" unless @size == entries.stops_at

    @rebuilds += 1
  end

  private def bin_table?(size)
    size > (1 >> MAX_POWER2_FOR_TABLES_WITHOUT_BINS)
  end

  private def allocated_entries
    1 << entry_power
  end

  private def rebuild_table_if_necessary
    rehash if entries.stops_at == allocated_entries
    raise "invalid stops_at" unless entries.stops_at < allocated_entries
  end

  def [](key)
    found, val = lookup(key)
    unless found
      raise KeyError.new "Missing hash key: #{key.inspect}"
    end
    val
  end

  def []?(key)
    _, val = lookup(key)
    val
  end

  def []=(key, value)
#    puts "Inserting #{key.to_s} : #{value.to_s}"
    insert(key, value)
  end

  # Insert KEY, VALUE into hash table.
  # Returns true if new key is inserted, false otherwise.
  private def insert(key, value)
    rebuild_table_if_necessary
    hash = do_hash(key)
    bins = @bins
    if bins
      entry_index, bin_index = bins.reserve_index(key, hash, entries)
      is_new = entry_index == Entries::UNDEFINED
    else
      entry_index = entries.index(key, hash)
      is_new = entry_index == Entries::UNDEFINED
      bin_index = Bins::UNDEFINED
    end
    if is_new
      @size += 1
      entry_index = entries.stops_at
      @entries = Entries.new(entries.entries, entries.starts_at, entries.stops_at + 1)

      if bin_index != Bins::UNDEFINED
        bins.not_nil!.set_bin(bin_index, entry_index)
      end
    end

    # p "inserting into entry_index #{entry_index}"
    # p @size
    entries[entry_index] = Entry.new(hash, key, value)
    is_new
  end

  MAX_POWER2 = 30u16

  # Power of 2 defining minimal number of allocated entries
  MINIMAL_POWER2 = 2u16

  # If power2 of allocated entries is less than this, don't allocate a
  # bins table and use linear search instead.
  MAX_POWER2_FOR_TABLES_WITHOUT_BINS = 4u16

  # Return smallest n >= MINIMAL_POWER2 such 2^n > size
  # Could use LLVM builtin llvm-clz
  private def power2(size)
    n = 0_u16
    while size != 0
      size >>= 1
      n += 1
    end
    if n <= MAX_POWER2
      n < MINIMAL_POWER2 ? MINIMAL_POWER2 : n
    else
      raise "Too many entries in hash table."
    end
  end

  # Reserved hash values are used for deleted entries. Substitute with
  # a different value:
  RESERVED_HASH_VALUE              = ~0
  RESERVED_HASH_SUBSTITUTION_VALUE = 0
  private def do_hash(key : K)
    hash = key.hash
    hash == RESERVED_HASH_VALUE ? RESERVED_HASH_SUBSTITUTION_VALUE : hash
  end

  REBUILD_THRESHOLD = 4

  def feature
    FEATURES[@entry_power]
  end

  record(Feature, entry_power : UInt8, bin_power : UInt8, bin_words : Int32)
  # Not certain this table make sense now that there isn't a variable bin index size.
  FEATURES = [
    {0_u8, 1_u8},
    {1_u8, 2_u8},
    {2_u8, 3_u8},
    {3_u8, 4_u8},
    {4_u8, 5_u8},
    {5_u8, 6_u8},
    {6_u8, 7_u8},
    {7_u8, 8_u8},
    {8_u8, 9_u8},
    {9_u8, 10_u8},
    {10_u8, 11_u8},
    {11_u8, 12_u8},
    {12_u8, 13_u8},
    {13_u8, 14_u8},
    {14_u8, 15_u8},
    {15_u8, 16_u8},
    {16_u8, 17_u8},
    {17_u8, 18_u8},
    {18_u8, 19_u8},
    {19_u8, 20_u8},
    {20_u8, 21_u8},
    {21_u8, 22_u8},
    {22_u8, 23_u8},
    {23_u8, 24_u8},
    {24_u8, 25_u8},
    {25_u8, 26_u8},
    {26_u8, 27_u8},
    {27_u8, 28_u8},
    {28_u8, 29_u8},
    {29_u8, 30_u8},
    {30_u8, 31_u8},
    # {31_u8, 32_u8},
    # {32_u8, 33_u8},
    # {33_u8, 34_u8, 0x400000000_i32},
    # {34_u8, 35_u8, 0x800000000_i32},
    # {35_u8, 36_u8, 0x1000000000_i32},
    # {36_u8, 37_u8, 0x2000000000_i32},
    # {37_u8, 38_u8, 0x4000000000_i32},
    # {38_u8, 39_u8, 0x8000000000_i32},
    # {39_u8, 40_u8, 0x10000000000_i32},
    # {40_u8, 41_u8, 0x20000000000_i32},
    # {41_u8, 42_u8, 0x40000000000_i32},
    # {42_u8, 43_u8, 0x80000000000_i32},
    # {43_u8, 44_u8, 0x100000000000_i32},
    # {44_u8, 45_u8, 0x200000000000_i32},
    # {45_u8, 46_u8, 0x400000000000_i32},
    # {46_u8, 47_u8, 0x800000000000_i32},
    # {47_u8, 48_u8, 0x1000000000000_i32},
    # {48_u8, 49_u8, 0x2000000000000_i32},
    # {49_u8, 50_u8, 0x4000000000000_i32},
    # {50_u8, 51_u8, 0x8000000000000_i32},
    # {51_u8, 52_u8, 0x10000000000000_i32},
    # {52_u8, 53_u8, 0x20000000000000_i32},
    # {53_u8, 54_u8, 0x40000000000000_i32},
    # {54_u8, 55_u8, 0x80000000000000_i32},
    # {55_u8, 56_u8, 0x100000000000000_i32},
    # {56_u8, 57_u8, 0x200000000000000_i32},
    # {57_u8, 58_u8, 0x400000000000000_i32},
    # {58_u8, 59_u8, 0x800000000000000_i32},
    # {59_u8, 60_u8, 0x1000000000000000_i32},
    # {60_u8, 61_u8, 0x2000000000000000_i32},
    # {61_u8, 62_u8, 0x4000000000000000_i32},
    # {62_u8, 63_u8, 0x8000000000000000_i32},
  ].map { |entry_power, bin_power| Feature.new(entry_power, bin_power, 1 << bin_power) }
end
