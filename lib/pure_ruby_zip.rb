module PureRubyZip
  class Error < StandardError; end
  # Your code goes here...
  CODE_LENGTH_CODES_ORDER = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
  LENGTH_EXTRA_BITS = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
  LENGTH_BASE = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163,
    195, 227, 258]
  DISTANCE_EXTRA_BITS = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13,
    13]
  DISTANCE_BASE = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049,
    3073, 4097, 6145, 8193, 12289, 16385, 24577]
  class Bitstream
    attr_accessor :byte
    attr_accessor :bit_index
    attr_accessor :file
    def initialize(data)
      @data = data
      @bit_index = 0
    end
    def read_bit
      res = ((@data[0].codepoints.first >> @bit_index) & 1) == 1
      if @bit_index == 7
        @data = @data[1..-1]
        @bit_index = 0
      else
        @bit_index += 1
      end
      res
    end
    def read_int(n_bits)
      res = 0
      (0..(n_bits - 1)).each { |i| res += (read_bit ? 1 : 0) << i }
      res
    end
  end
  class ZipDecompressor
    def decode_symbol(tree, file_bitstream)
      bits = []
      while true
        bit = file_bitstream.read_bit
        bits += [bit]
        key = bits.map { |x| x ? "1" : "0" }.join("")
        return tree[key] if tree[key]
      end
    end
    def inflate_block_data(litlen_tree, dist_tree, file_data, file_bitstream)
      data = file_data
      loop do
        sym = decode_symbol(litlen_tree, file_bitstream)
        if sym < 256
          data += sym.chr
        elsif sym == 256
          return data
        else
          sym -= 257
          length = file_bitstream.read_int(LENGTH_EXTRA_BITS[sym]) + LENGTH_BASE[sym]
          dist_sym = decode_symbol(dist_tree, file_bitstream)
          dist = file_bitstream.read_int(DISTANCE_EXTRA_BITS[dist_sym]) + DISTANCE_BASE[dist_sym]
          reference_data = []
          (0..(length - 1)).each {
            char = data[-dist]
            data += char
            reference_data += [char]
          }
          x = reference_data[0..10].join("").codepoints.join(" ")
        end
      end
      data
    end
    def bit_lengths_to_tree(bit_lengths)
      max_bits = bit_lengths.max
      bitlen_counts = (0..max_bits).map { |count| bit_lengths.count { |length| length == count && length != 0 } }
      next_code = [0, 0]
      (2..max_bits).each do |i|
        next_code[i] = ((next_code[i - 1] || 0) + bitlen_counts[i - 1]) << 1
      end
      tree = {}
      bit_lengths.each.with_index do |length, index|
        if length != 0
          tree[next_code[length].to_s(2).rjust(length, "0")] = index
          next_code[length] += 1
        end
      end
      tree
    end
    def decode_uncompressed_block(file_data, file_bitstream)
      file_bitstream.read_int(5)
      length = file_bitstream.read_int(16)
      file_bitstream.read_int(16)
      (0..(length - 1)).map { |x| file_bitstream.read_int(8).chr }.join("")
    end
    def decode_fixed_huffman_compressed_block(file_data, file_bitstream)
      litlen_bit_lengths = [8] * 144 + [9] * (256 - 144) + [7] * (280 - 256) + [8] * (286 - 280)
      litlen_tree = bit_lengths_to_tree(litlen_bit_lengths)
      dist_bit_lengths = [5] * 30
      dist_tree = bit_lengths_to_tree(dist_bit_lengths)
      inflate_block_data(litlen_tree, dist_tree, file_data, file_bitstream)
    end
    def decode_dynamic_huffman_compressed_block(file_data, file_bitstream)
      hlit = file_bitstream.read_int(5) + 257
      hdist = file_bitstream.read_int(5) + 1
      hclen = file_bitstream.read_int(4) + 4
      code_length_bit_lengths = [0] * 19
      (0..(hclen - 1)).each { |len| code_length_bit_lengths[CODE_LENGTH_CODES_ORDER[len]] = file_bitstream.read_int(3) }
      code_length_tree = bit_lengths_to_tree(code_length_bit_lengths)
      bit_lengths = []
      while bit_lengths.count < hlit + hdist
        sym = decode_symbol(code_length_tree, file_bitstream)
        if sym < 16
          bit_lengths += [sym]
        elsif sym == 16
          prev_byte = bit_lengths[-1]
          bit_lengths += [prev_byte] * (file_bitstream.read_int(2) + 3)
        elsif sym == 17
          bit_lengths += [0] * (file_bitstream.read_int(3) + 3)
        elsif sym == 18
          bit_lengths += [0] * (file_bitstream.read_int(7) + 11)
        end
      end
      litlen_tree = bit_lengths_to_tree(bit_lengths[0..(hlit - 1)])
      dist_tree = bit_lengths_to_tree(bit_lengths[hlit..-1])
      inflate_block_data(litlen_tree, dist_tree, file_data, file_bitstream)
    end
    def decode_zipped_file(file_bitstream)
      file_data = ""
      is_last_block = false
      until is_last_block
        is_last_block = file_bitstream.read_bit
        block_type = file_bitstream.read_int(2)
        file_data += if block_type == 0
          decode_uncompressed_block(file_data, file_bitstream)
        elsif block_type == 1
          decode_fixed_huffman_compressed_block(file_data, file_bitstream)
        else
          decode_dynamic_huffman_compressed_block(file_data, file_bitstream)
        end
      end
      file_data
    end
  end
  module ZipHelpers
    def read_int(file, bytes)
      file.read(bytes).codepoints.each.with_index.reduce(0) { |acc, x| acc + ((x[1] == 0) ? x[0] : x[0] * (256 * x[1])) }
    end
    def find_string(file, string)
      search_fifo = ""
      while search_fifo != string
        search_fifo = (search_fifo.length == 4 ? search_fifo[1..-1] : search_fifo) + file.read(1)
      end
    end
    def skip(file, bytes)
      file.read bytes
    end
  end
  class ZipFileItem
    include ZipHelpers
    def initialize(filename, offset)
      @filename = filename
      @offset = offset
    end
    def read_data(zipfile)
      # Skip to compressed length
      skip zipfile, 8
      # Get compressed length
      compressed_size = read_int zipfile, 4
      # Skip to extra data length
      skip zipfile, 6
      # Get extra data length
      extra_data_length = read_int zipfile, 2
      # Skip to file data
      skip zipfile, @filename.length + extra_data_length
      # Read file data
      zipfile.read compressed_size
    end
    def handle_compressed(zipfile)
      data = read_data zipfile
      File.open("data2.dat", "w") { |file| file.write(data) }
      b = Bitstream.new data
      z = ZipDecompressor.new
      z.decode_zipped_file b
    end
    def handle_uncompressed(zipfile)
      read_data zipfile
    end
    def get_decompressed_data(zipfile)
      zipfile.seek @offset
      # Skip to compression type
      skip zipfile, 8
      # Read compression type
      compression_type = read_int zipfile, 2
      data = if compression_type == 8
        handle_compressed zipfile
      else
        handle_uncompressed zipfile
      end
    end
  end
  class ZipFile
    include ZipHelpers
  private
    def find_eocd(file)
      find_string file, "\x50\x4b\x05\x06"
    end
    def find_central_directory(file)
      find_string file, "\x50\x4b\x01\x02"
    end
    def get_number_of_items(file)
      # Find the EOCD (End Of Central Directory)
      find_eocd file
      # Skip to number of entries (items in zipfile)
      skip file, 6
      # Read number of entries
      num_entries = read_int file, 2
    end
    def get_items_metadata(file)
      File.open(@filename) do |file|
        # Read number of entries
        num_entries = get_number_of_items file
        # Rewind file
        file.seek 0
        @items = Hash[(0..(num_entries - 1)).map {
          # Find central directory record
          find_central_directory file
          # Skip to filename length
          skip file, 24
          # Get filename length
          filename_length = read_int file, 2
          # Skip to file offset
          skip file, 12
          # Get file offset
          file_offset = read_int file, 4
          # Get filename
          filename = file.read(filename_length)
          [filename, ZipFileItem.new(filename, file_offset)]
        }]
      end
    end
  public
    def initialize(filename)
      @filename = filename
      get_items_metadata @filename
    end
    def decompress_file(path)
      File.open(@filename) do |file|
        @items[path].get_decompressed_data file
      end
    end
    def decompress_all_files
      decompressed_files = []
      File.open(@filename) do |file|
        decompressed_files = @items.keys.map do |path|
          {
            path: path,
            data: @items[path].get_decompressed_data(file)
          }
        end
      end
      decompressed_files
    end
    def decompress_all_files_to_disk
      dir_of_zip_file = File.dirname(@filename)
      zipfile_without_extension = File.basename @filename, ".*"
      extract_dir_path = "#{dir_of_zip_file}/#{zipfile_without_extension}"
      Dir.mkdir(extract_dir_path) unless Dir.exist?(extract_dir_path)
      decompress_all_files.each do |decompressed_item|
        path = decompressed_item[:path]
        data = decompressed_item[:data]
        file_extract_path = "#{extract_dir_path}/#{path}"
        File.open(file_extract_path, "w") do |extracted_file|
          extracted_file.write data
        end
      end
    end
  end
end
