module RB_DICOM
  DATA_DICT = { 
    '00080005'=>'CS',   # specific character set
    '00080050'=>'SH',   # accession number
    '00080060'=>'CS',   # modality
    '00080080'=>'LO',   # institution name
    '00080090'=>'PN',   # referring physician's name
    '00100010'=>'PN',   # patient's name
    '00100020'=>'LO',   # patient's ID
    '00100030'=>'DA',   # patient's birthdate
    '00100040'=>'CS',   # patient's sex
    '00101030'=>'DS',   # patient's weight
    '00102000'=>'LO',   # medical alerts
    '00102110'=>'LO',   # allergies
    '0020000d'=>'UI',   # study instance UID
    '00321032'=>'PN',   # requesting physician
    '00321033'=>'LO',   # requesting service
    '00321060'=>'LO',   # requested procedure description
    '00321070'=>'LO',   # requested contrast agent
    '00380010'=>'LO',   # admission ID
    '00380050'=>'LO',   # special needs
    '00380300'=>'LO',   # current patient location
    '00380400'=>'LO',   # patient's institution residence
    '00380500'=>'LO',   # patient state
    '00400001'=>'AE',   # scheduled station AE title
    '00400002'=>'DA',   # scheduled procedure step date
    '00400003'=>'TM',   # scheduled procedure step time
    '00400006'=>'PN',   # scheduled performing physician's name
    '00400007'=>'LO',   # scheduled procedure step description
    '00400009'=>'SH',   # scheduled procedure step ID
    '00400010'=>'LO',   # scheduled station name
    '00400012'=>'LO',   # premedication
    '00400020'=>'CS',   # scheduled procedure step status
    '00400100'=>'SQ',   # scheduled procedure step sequence
    '00401001'=>'SH',   # requested procedure ID
    '00401002'=>'LO',   # reason for the requested procedure
    '00401003'=>'SH',   # requested procedure priority
    '00401004'=>'LO',   # patient transport arrangement
    '00401400'=>'LO',   # requested procedure comments
    '00402016'=>'LO',   # placer order number
    '00402017'=>'LO',   # filler order number
    '00403001'=>'LO'    # confidentiality constraint
  }
  
  RELEASE_REQUEST = [0x05, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00].pack("C*")
end
