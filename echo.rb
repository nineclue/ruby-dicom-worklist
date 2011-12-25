require 'eventmachine'
require './model'

include RB_DICOM

# echo
request = Association.new({:pdu_type=>1})
pc = PresentationContext.new
pc.syntax_or_result = ContextItem.new({:type=>0x30, :data=>'1.2.840.10008.1.1'})
pc.transfer_syntax[0] = ContextItem.new({:type=>0x40, :data=>'1.2.840.10008.1.2'})
request.pcontext[0] = pc
request.user_info = ContextItem.new({:type=>0x50})
request.user_info.data << ContextItem.new({:type=>0x51})
request.user_info.data << ContextItem.new({:type=>0x52, :data=>'1.2.276.0.7230010.3.0.3.6.0'})
request.user_info.data << ContextItem.new({:type=>0x55, :data=>'OFFIS_DCMTK_360'})
request.user_info.update_length
bin = request.to_binary_s
p request.snapshot
hex_print(bin)

com = PCommand.new({:context_id=>1})
com.commands << CommandElement.new_element('00000000')
# com.commands << CommandElement.new({:telement=>0})
com.commands << CommandElement.new({:telement=>2, :data=>'1.2.840.10008.1.1 '})
com.commands << CommandElement.new({:telement=>0x100, :data=>0x30})
com.commands << CommandElement.new({:telement=>0x110, :data=>1})
com.commands << CommandElement.new({:telement=>0x800, :data=>257})
com.post_process
p com.snapshot
hex_print(com.to_binary_s)

class Communication < EM::Connection
  
  def initialize(association, command, data, check_proc)
    @association = association
    @command = command
    @data = data
    @check_proc = check_proc
    @status = :initialized
    @buffer = ''
    puts "initialized... #{check_proc.class}"
  end
    
  def post_init
    send_data(@association)
    @status = :connected
  end

  def receive_data(data)
    @buffer << data
    case @status
    when :connected
      # check association
      if true then
        puts 'associated...'
        @status = :associated
        @buffer.clear
        send_data(@command)
        send_data(@data)
      end
    when :associated
      if @check_proc.call(@buffer) then
        puts 'received data, finished...'
        @status = :releasing
        @buffer.clear
        send_data(RELEASE_REQUEST)
      end
    when :releasing
      #check release
      if true then
        puts 'releasing...'
        @status = :finished
        @buffer.clear
        close_connection
      end
    end
  end
end

EM.run do
  p = Proc.new do |buffer| 
    puts "check function... #{buffer}"
    true 
  end
  a = EM.connect('0.0.0.0', 8080, Communication, "ASSOCIATION", "COMMAND", "DATA", p)
end
