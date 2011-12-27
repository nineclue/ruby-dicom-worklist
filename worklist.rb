require 'eventmachine'
require './model'

include RB_DICOM

# modality worklist
association = Association.new({:pdu_type=>1})
pc = PresentationContext.new
pc.syntax_or_result = ContextItem.new({:type=>0x30, :data=>'1.2.840.10008.5.1.4.31'})
pc.transfer_syntax[0] = ContextItem.new({:type=>0x40, :data=>'1.2.840.10008.1.2.1'})
association.pcontext[0] = pc
association.user_info = ContextItem.new({:type=>0x50})
association.user_info.data << ContextItem.new({:type=>0x51})
association.user_info.data << ContextItem.new({:type=>0x52, :data=>'1.2.826.0.1.3680043.9.445.1'})
association.user_info.data << ContextItem.new({:type=>0x55, :data=>'RB_DICOM'})
association.user_info.update_length

com = PCommand.new({:context_id=>1})
com.commands << CommandElement.new_element('00000000')
com.commands << CommandElement.new({:telement=>2, :data=>'1.2.840.10008.5.1.4.31'})
com.commands << CommandElement.new({:telement=>0x100, :data=>0x20})
com.commands << CommandElement.new({:telement=>0x110, :data=>1})
com.commands << CommandElement.new({:telement=>0x700, :data=>0})
com.commands << CommandElement.new({:telement=>0x800, :data=>0})
com.post_process

dat = PData.new
dat.data << DataElement.new_element('00080005')         # encoding
dat.data << DataElement.new_element('00100010', '* ')   # name
dat.data << DataElement.new_element('00100020', '* ')   # chart no
dat.data << DataElement.new_element('00100030')         # birthdate
dat.data << DataElement.new_element('00321032')         # associationing physician
dat.data << DataElement.new_element('00321060')         # procedure description
dat.data << DataElement.new_element('00400100')         # sequence
dat.add_to_sequence DataElement.new_element('00080060', '* ')  # modality
today = Time::now.strftime('%Y%m%d')
dat.add_to_sequence DataElement.new_element('00400002', "#{today}-#{today} ")   # examdate
dat.data << DataElement.new_element('00401002')         # reason for procedure
dat.data << DataElement.new_element('00401400')         # comments
dat.post_process

EM.run do
  p = Proc.new do |dict|
    dict.each do |d|
      puts "(%s) %s - %s (%s) (%s)" % [d['00100020'], d['00100010'], d['00321060'], d['00401002'], d['00401400']]
    end
  end
  EM.connect(ARGV[0], ARGV[1].to_i, Communication, association.to_binary_s, com.to_binary_s, dat.to_binary_s, p)
end
