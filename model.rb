require 'bindata'
require './constants'

module RB_DICOM
  class DataElement < BinData::Record; end      # forward declaration

  class SequenceItem < BinData::Record
    endian  :little
    
    uint16  :tgroup, :value=>0xfffe
    uint16  :telement, :value=>0xe000
    uint32  :dlength      # numbytes - (group(2) + element(2) + length(4))
    array   :data, :type=>:data_element
    uint32  :delimiter, :value=>0xfffee00d, :onlyif=>lambda{dlength==0xffffffff}
    uint32  :delimiter_length, :value=>0, :onlyif=>lambda{dlength==0xffffffff}
  end

  class DataElement < BinData::Record
    # cannot use endian after forward declaration! 
    # sequence cause many many troubles... :(
    uint16le  :tgroup
    uint16le  :telement
    string    :vr, :length=>2
    skip      :length=>2 , :onlyif=>lambda {vr=='SQ'}
    choice    :dlength, :selection=>:vr do
      uint32le        'SQ'          ,:check_value=>lambda { value.even? }
      uint16le        :default      ,:check_value=>lambda { value.even? }
    end
    # uint16le  :dlength, :value=>lambda{ num_bytes-8 }, :check_value=>lambda{ value.even? }
    choice  :data, :selection=>:vr do
      int32le         'AT'  # attribute tag
      float_le        'FL'  # floating point single
      double_le       'FD'  # floating point double
      int32le         'SL'  # signed long
      # array     'SQ', :type=>:sequence_item    # sequence
      sequence_item   'SQ'  # sequence
      int16le         'SS'  # signed short
      uint32le        'UL'  # unsigned long
      uint16le        'US'  # unsigned short
      string          :default, :pad_char=>0x20, :read_length=>:dlength
    end

    def self.new_element(tag, data=nil)
      raise "Unknown or wrong tag : #{tag}" if tag.length != 8 or DATA_DICT[tag].nil?
      group = tag[0..3].to_i(16)
      element = tag[4..-1].to_i(16)
      if data.nil?
        new({:tgroup=>group, :telement=>element, :vr=>DATA_DICT[tag]})
      else
        new({:tgroup=>group, :telement=>element, :vr=>DATA_DICT[tag], :data=>data})
      end
    end
    
    # :value=>lambda { num_bytes... } cause 'stack too deep' at choice
    # called by PData.post_process
    def update_sequence
      return unless vr == 'SQ'
      data.data.each do |datum|
        datum.dlength = datum.num_bytes - 8
        if datum.vr == 'SQ' then
          datum.dlength -= 4
          datum.update_sequence 
        end
        raise "data element data size must be even #{'(%04x,%04x):%s(%d)' %  
          [datum.tgroup, datum.telement, datum.data, datum.dlength]}" if datum.dlength.odd? and datum.vr != 'SQ'
      end
    end
  end
    
  class CommandElement < BinData::Record
    endian  :little
    
    uint16  :tgroup, :initial_value=>0
    uint16  :telement
    # TODO - affected SOP class string itself is 17 bytes, but value is 18 bytes with 0 padded
    # tag : 4bytes, length : 4bytes
    uint32  :dlength, :value=>lambda {num_bytes - 8}, :check_value=>lambda { value.even? }      
    # uint32  :dlength, :value=>lambda {data.size}, :check_value=>lambda { value.even? }      
    choice  :data, :selection=>:tag do
      uint32    '00000000', :initial_value=>0             # command group length
      string    '00000002', :read_length=>:dlength        # affected SOP class UID
      uint16    :default, :initial_value=>0
    end

    def self.new_element(tag)
      raise if tag.length != 8
      group = tag[0..3].to_i(16)
      element = tag[4..-1].to_i(16)
      new({:tgroup=>group, :telement=>element})
    end
    
    def tag
      "%04x%04x" % [tgroup, telement]
    end
  end
  
  class PCommand < BinData::Record
    endian    :little
    
    uint8     :type, :value=>0x04
    skip      :length=>1
    uint32be  :ulength, :value=>lambda {num_bytes - 6}      # type(1) + skip(1) + ulength(4)
    uint32be  :vlength, :value=>lambda {num_bytes - 10}
    uint8     :context_id, :initial_value=>1
    struct    :msh do        # message control header
      bit6    :unused
      bit1    :last_flag, :initial_value=>1   # default last fragment
      bit1    :command_flag, :value=>1        # 1 is for command
    end
    # read_until : commands[0] value is rest of command size except group length itself (12)
    array     :commands, :type=>:command_element, :read_until=>lambda {array.num_bytes == commands[0].data+12}
    
    def post_process
      commands.each do |command|
        if command.tgroup == 0 and command.telement == 0 then
          command.data.assign(vlength-14)
        end
        raise "command element data size must be even #{'(%04x,%04x)' %  
                [command.tgroup, command.telement]}" unless command.dlength.even?
      end
    end
  end
  
  class PData < BinData::Record
    endian    :little
    
    uint8     :type, :value=>0x04
    skip      :length=>1
    uint32be  :ulength, :value=>lambda {num_bytes - 6}
    uint32be  :vlength, :value=>lambda {num_bytes - 10}
    uint8     :context_id, :initial_value=>1
    struct    :msh do        # message control header
      bit6    :unused
      bit1    :last_flag, :initial_value=>1   # default last fragment
      bit1    :command_flag, :value=>0        # 0 is for data
    end
    array     :data, :type=>:data_element, :read_until=>lambda {array.num_bytes == vlength-2}
    
    def add_to_sequence(element, sindex=0)
      index = 0
      data.each do |datum|
        if datum.vr == 'SQ' then
          if index == sindex then
            datum.data.data << element
            datum.data.dlength = datum.data.num_bytes - 8
          else
            index += 1
          end
        end
      end
    end
    
    # :value=>lambda { num_bytes... } cause 'stack too deep' at choice
    def post_process
      data.each do |datum|
        datum.dlength = datum.num_bytes - 8
        if datum.vr == 'SQ' then
          datum.dlength -= 4
          datum.update_sequence 
        end
        raise "data element data size must be even #{'(%04x,%04x):%s(%d)' %  
          [datum.tgroup, datum.telement, datum.data, datum.dlength]}" if datum.dlength.odd? and datum.vr != 'SQ'
      end
    end
  end
  
  class ContextItem < BinData::Record
    uint8     :type, :initial_value=>0
    skip      :length=>1
    uint16be  :dlength, :value=>lambda {num_bytes-4}
    choice    :data, :selection=>:type do
      uint32le  0x51, :initial_value=>16384                     # max PDU length
      array     0x50, :type=>:context_item, :initial_length=>3  # user info, capable of only 3 items
      string    :default, :read_length=>:dlength
    end
    
    def update_length
      dlength.assign(num_bytes-4)
    end
  end
  
  class PresentationContext < BinData::Record
    uint8     :type, :initial_value=>0x20
    skip      :length=>1
    uint16be  :dlength, :initial_value=>lambda {num_bytes-4}
    uint8     :pid, :initial_value=>1
    choice    :blank, :selection => :type do
      skip      0x20, :length=>3
      skip      0x21, :length=>1
    end
    choice    :syntax_or_result, :selection => :type do
      context_item    0x20
      uint8           0x21
    end
    uint8     :blank2, :onlyif=>lambda {type==0x21}
    array     :transfer_syntax, :type=>:context_item, :initial_length=>1
  end
  
  class Association < BinData::Record
    uint8     :pdu_type
    skip      :length=>1
    uint32be  :pdu_length, :value=>lambda {num_bytes-6}
    uint16be  :protocol, :initial_value=>1
    skip      :length=>2
    string    :called_title, :length=>16, :initial_value=>'ANY-SCP', :pad_char=>0x20
    string    :calling_title, :length=>16, :initial_value=>'ECHOSCU', :pad_char=>0x20
    skip      :length=>32
    struct    :application_context do
      uint8     :item_type, :value=>0x10
      skip      :length=>1
      uint16be  :ac_length, :value=>lambda {ac_name.length}
      string    :ac_name, :read_length=>:ac_length, :initial_value=>'1.2.840.10008.3.1.1.1'
    end
    array     :pcontext, :type=>:presentation_context, :initial_length=>1
    context_item  :user_info
  end
  
  def hex_print(str)
    puts "size : #{str.length}"
    0.step(str.length-1, 16) do |i|
      output = '00  '*16
      upper = str.length - i - 1
      upper = 15 if upper > 15
      0.step(upper) do |j|
        output[(j*4)..(j*4+1)] = '%02x' % str[i+j].ord
        #puts "#{i+j} : #{str[i+j]} - #{str[i+j].ord} #{'%02x' % str[i+j].to_i}"       
      end
      puts '%04x : %s' % [i, output]
    end
  end
end