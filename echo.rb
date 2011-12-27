require 'eventmachine'
require './model'

include RB_DICOM

# echo
association = Association.new({:pdu_type=>1})
pc = PresentationContext.new
pc.syntax_or_result = ContextItem.new({:type=>0x30, :data=>'1.2.840.10008.1.1'})
pc.transfer_syntax[0] = ContextItem.new({:type=>0x40, :data=>'1.2.840.10008.1.2'})
association.pcontext[0] = pc
association.user_info = ContextItem.new({:type=>0x50})
association.user_info.data << ContextItem.new({:type=>0x51})
association.user_info.data << ContextItem.new({:type=>0x52, :data=>'1.2.826.0.1.3680043.9.445.1'})
association.user_info.data << ContextItem.new({:type=>0x55, :data=>'RB_DICOM'})
association.user_info.update_length

com = PCommand.new({:context_id=>1})
com.commands << CommandElement.new_element('00000000')
com.commands << CommandElement.new({:telement=>2, :data=>'1.2.840.10008.1.1 '})
com.commands << CommandElement.new({:telement=>0x100, :data=>0x30})
com.commands << CommandElement.new({:telement=>0x110, :data=>1})
com.commands << CommandElement.new({:telement=>0x800, :data=>257})
com.post_process

EM.run do
  EM.connect(ARGV[0], ARGV[1].to_i, Communication, association.to_binary_s, com.to_binary_s, nil, nil)
end
