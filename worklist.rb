require 'eventmachine'
require './model'

include RB_DICOM

# modality worklist
request = Association.new({:pdu_type=>1})
pc = PresentationContext.new
pc.syntax_or_result = ContextItem.new({:type=>0x30, :data=>'1.2.840.10008.5.1.4.31'})
pc.transfer_syntax[0] = ContextItem.new({:type=>0x40, :data=>'1.2.840.10008.1.2.1'})
request.pcontext[0] = pc
request.user_info = ContextItem.new({:type=>0x50})
request.user_info.data << ContextItem.new({:type=>0x51})
request.user_info.data << ContextItem.new({:type=>0x52, :data=>'1.2.826.0.1.3680043.9.445.1'})
request.user_info.data << ContextItem.new({:type=>0x55, :data=>'RB_DICOM'})
request.user_info.update_length
association = request.to_binary_s
p request.snapshot
hex_print(association)

com = PCommand.new({:context_id=>1})
com.commands << CommandElement.new_element('00000000')
com.commands << CommandElement.new({:telement=>2, :data=>'1.2.840.10008.5.1.4.31'})
com.commands << CommandElement.new({:telement=>0x100, :data=>0x20})
com.commands << CommandElement.new({:telement=>0x110, :data=>1})
com.commands << CommandElement.new({:telement=>0x700, :data=>0})
com.commands << CommandElement.new({:telement=>0x800, :data=>0})
com.post_process
p com.snapshot
hex_print(com.to_binary_s)

dat = PData.new
dat.data << DataElement.new_element('00080005')
dat.data << DataElement.new_element('00100010', '* ')
dat.data << DataElement.new_element('00100020', '* ')
dat.data << DataElement.new_element('00100030')
dat.data << DataElement.new_element('00400100')
dat.add_to_sequence DataElement.new_element('00080060', '* ')
today = Time::now.strftime('%Y%m%d')
dat.add_to_sequence DataElement.new_element('00400002', "#{today}-#{today} ")
dat.post_process
p dat.snapshot
hex_print(dat.to_binary_s)

class Communication < EM::Connection
  
  def initialize(association, command, data, check_proc)
    @association = association
    @command = command
    @data = data
    @check_proc = check_proc
    @status = :initialized
    @buffer = ''
  end
    
  def post_init
    puts 'post_init : sending association'
    send_data(@association)
    @status = :connected
  end

  def receive_data(data)
    puts "received data... #{@status}"
    @buffer << data
    case @status
    when :connected
      association_rsp = Association.read(@buffer)
      if association_rsp.pcontext[0].syntax_or_result == 0 then
        puts 'associated..., now sending command/data'
        @status = :associated
        @buffer.clear
        send_data(@command)
        send_data(@data) unless @data.nil?
      end
    when :associated
      if @check_proc.call(@buffer) then
        puts 'received data, finished...'
        @status = :releasing
        @buffer.clear
        send_data(RELEASE_REQUEST)
      end
    when :releasing
      if @buffer = RELEASE_RESPONSE then
        puts 'successful release...'
        @status = :finished
        @buffer.clear
        close_connection
        EM.stop
      end
    end
  end
end

EM.run do
  # p1 = Proc.new do |buffer|
  #   fn = Time::now.to_f.to_s
  #   puts "writing... #{fn}"
  #   open(fn, 'w') { |f| f.write(buffer) }
  #   false
  # end
  p = Proc.new do |buffer|
    puts "check function..."
    size = 0
    com_rsp = dat_rsp = nil
    while size < buffer.size
      data_size = buffer[size+2..size+5].unpack('N')[0]
      # BinData::trace_reading do
      if (buffer[size+11].ord & 1) == 1
        com_rsp = PCommand.read(buffer[size..(size+data_size+6)])
        size += com_rsp.num_bytes
      else
        dat_rsp = PData.read(buffer[size..(size+data_size+6)])
        puts dat_rsp.data[1].data.force_encoding('EUC-KR').encode('UTF-8')
        size += dat_rsp.num_bytes
      end
      #end
    end
    (!com_rsp.nil?) and (com_rsp.commands[-1].data == 0)
  end
  # Dir.glob('*').sort.each do |fn|
  #   if /\d+.\d+/ =~ fn
  #     buff = open(fn, 'rb') { |f| f.read }
  #     p.call(buff)
  #   end
  # end
  # EM.next_tick { EM.stop }
  EM.connect('0.0.0.0', 8080, Communication, association, com.to_binary_s, dat.to_binary_s, p)
  # EM.connect(ARGV[0], ARGV[1].to_i, Communication, association, com.to_binary_s, nil, p)
end
