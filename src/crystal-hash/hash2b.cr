class Hash2b(K, V)
  include Enumerable({K, V})
  include Iterable({K, V})

  getter size : Int32
  getter first : Int32?
  getter last : Int32?

  record(Entry, hash : Int32, key : K, value : V)

  struct Bins
    EMPTY           = 0
    DELETED         = 1
    BASE            = 2
    UNDEFINED_INDEX = ~0

    property bins : Slice(Int32)

    def initialize(size)
      @bins = Slice(Int32).new(initial_capacity, EMPTY)
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
      assert i != UNDEFINED_INDEX
      assert !empty_or_deleted?(i)
      set_bin(i, DELETED)
    end

    def mark_empty(i : Int32)
      set_bin(i, EMPTY)
    end

    # TODO: ruby version uses variable index sizes depending on size
    # of bin table. Should that be done here as well?
    def set_bin(n, v)
      bins[n] = v
    end

    def bin_count
      bins.size
    end

    def bins_mask
      bin_count - 1
    end

    def hash_bin(hash)
      hash & bins_mask
    end

    def clear
      @bins.clear
    end
  end

  struct Entries
    property entries : Slice(Entry)
    property starts_at
    property stops_at

    UNDEFINED_INDEX = ~0

    def initialize(size)
      @entries = Slice(Entry).new(size)
      @starts_at = 0
      @stops_at = 0
    end

    def mark_deleted(i)
      entries[i].hash = RESERVED_HASH_VALUE
    end

    def deleted?(i)
      entries[i].hash == RESERVED_HASH_VALUE
    end

    def size
      entries.size
    end

    def clear
      @starts_at = @stops_at = 0
    end
  end

  def initialize(block : (Hash(K, V), K -> V)? = nil, initial_capacity = 0)
    @size = 0
    @rebuilds = 0
    @entry_power = power2(initial_capacity)
    @bin_power = feature.bin_power
    if n <= MAX_POWER2_FOR_TABLES_WITHOUT_BINS
      @bins = nil
    else
      @bins = Bins.new(feature.bins_words)
    end

    @entries = Entries.new(allocated_entries)
  end

  private def allocated_entries
    1 << entry_power
  end

  def []=(key : K, value : V)
  end

  def delete(key)
  end

  def each : Nil
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
    bound = entries.stops_at
    current_allocation = allocated_entries
    if (2 * size <= current_allocation &&
       REBUILD_THRESHOLD * @size > allocated_entries) ||
       @size < 1 << MINIMAL_POWER2
      # compaction
      @size = 0
      @bins.clear if @bins
      # FIXME
    else
      # FIXME
    end
  end

  private def bin_table?(size)
    size > (1 >> MAX_POWER2_FOR_TABLES_WITHOUT_BINS)
  end

  protected def find_entry(key)
    # FIXME
    # index = bucket_index key
    # entry = @buckets[index]
    # find_entry_in_bucket entry, key
  end

  private def insert_in_bucket(index, key, value)
  end

  private def find_entry_in_bucket(entry, key)
    # FIXME
    # while entry
    #   if entry.key == key
    #     return entry
    #   end
    #   entry = entry.next
    # end
    # nil
  end

  MAX_POWER2 = 62

  # Power of 2 defining minimal number of allocated entries
  MINIMAL_POWER2 = 2

  # If power2 of allocated entries is less than this, don't allocate a
  # bins table and use linear search instead.
  MAX_POWER2_FOR_TABLES_WITHOUT_BINS = 4

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
  RESERVED_HASH_VAL              = ~0
  RESERVED_HASH_SUBSTITUITON_VAL = 0
  private def do_hash(key : K)
    hash = key.hash
    hash == RESERVERD_HASH_VAL ? RESERVED_HASH_SUBSTITUTION_VAL : hash
  end

  REBUILD_THRESHOLD = 4

  def feature
    FEATURES[@entry_power]
  end

  record(Feature, entry_power : UInt8, bin_power : UInt8, bins_words : UInt64)
  FEATURES = [
    {0, 1, 0x0},
    {1, 2, 0x1},
    {2, 3, 0x1},
    {3, 4, 0x2},
    {4, 5, 0x4},
    {5, 6, 0x8},
    {6, 7, 0x10},
    {7, 8, 0x20},
    {8, 9, 0x80},
    {9, 10, 0x100},
    {10, 11, 0x200},
    {11, 12, 0x400},
    {12, 13, 0x800},
    {13, 14, 0x1000},
    {14, 15, 0x2000},
    {15, 16, 0x4000},
    {16, 17, 0x10000},
    {17, 18, 0x20000},
    {18, 19, 0x40000},
    {19, 20, 0x80000},
    {20, 21, 0x100000},
    {21, 22, 0x200000},
    {22, 23, 0x400000},
    {23, 24, 0x800000},
    {24, 25, 0x1000000},
    {25, 26, 0x2000000},
    {26, 27, 0x4000000},
    {27, 28, 0x8000000},
    {28, 29, 0x10000000},
    {29, 30, 0x20000000},
    {30, 31, 0x40000000},
    {31, 32, 0x80000000},
    {32, 33, 0x200000000},
    {33, 34, 0x400000000},
    {34, 35, 0x800000000},
    {35, 36, 0x1000000000},
    {36, 37, 0x2000000000},
    {37, 38, 0x4000000000},
    {38, 39, 0x8000000000},
    {39, 40, 0x10000000000},
    {40, 41, 0x20000000000},
    {41, 42, 0x40000000000},
    {42, 43, 0x80000000000},
    {43, 44, 0x100000000000},
    {44, 45, 0x200000000000},
    {45, 46, 0x400000000000},
    {46, 47, 0x800000000000},
    {47, 48, 0x1000000000000},
    {48, 49, 0x2000000000000},
    {49, 50, 0x4000000000000},
    {50, 51, 0x8000000000000},
    {51, 52, 0x10000000000000},
    {52, 53, 0x20000000000000},
    {53, 54, 0x40000000000000},
    {54, 55, 0x80000000000000},
    {55, 56, 0x100000000000000},
    {56, 57, 0x200000000000000},
    {57, 58, 0x400000000000000},
    {58, 59, 0x800000000000000},
    {59, 60, 0x1000000000000000},
    {60, 61, 0x2000000000000000},
    {61, 62, 0x4000000000000000},
    {62, 63, 0x8000000000000000},
  ].map { |t| Feature.new(*t) }
end
