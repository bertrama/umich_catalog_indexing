$:.unshift  "#{File.dirname(__FILE__)}/../lib"

require 'library_stdnums'

require 'traject/macros/marc21_semantics'
extend  Traject::Macros::Marc21Semantics

require 'traject/macros/marc_format_classifier'
extend Traject::Macros::MarcFormats

require 'ht_macros'
require 'ht_item'
extend HathiTrust::Traject::Macros

 

settings do
  store "log.batch_progress", 10_000
end

logger.info RUBY_DESCRIPTION

# Get ready to map marc4j record into an xml string
marc_converter = MARC::MARC4J.new(:jardir => settings['marc4j_reader.jar_dir'])

################################
###### Setup ###################
################################

# Set up an area in the clipboard for use storing intermediate stuff
each_record HathiTrust::Traject::Macros.setup


# Force rights if we're working without

if ENV['FORCE_RIGHTS']
  each_record do |rec|
    rec.fields('974').each do |f|
      sf = MARC::Subfield.new('r', 'ic')
      f.append sf
    end
  end
end


# Get a marc4j record if we don't have one already
each_record do |rec, context|
  context.clipboard[:ht][:marc4j] = marc_converter.rubymarc_to_marc4j(rec)
end



################################
###### CORE FIELDS #############
################################

to_field "id", extract_marc("001", :first => true)
to_field 'fullrecord', macr4j_as_xml
to_field "allfields", extract_all_marc_values

# Get a formatter
require 'MARCFormat.jar'
format_extractor = Java::org.marc4j::GetFormat.new
format_map       = Traject::TranslationMap.new("ht/formats")

to_field "format" do |record, acc, context|
  f = format_extractor.get_content_types_and_media_types(context.clipboard[:ht][:marc4j]).map{|c| format_map[c.to_s]}
  f.flatten!
  f.compact!
  f.uniq!
  acc.concat f
  
  # We need to know for later if this is a serial/journal type
  if acc.include? "Journal"
    context.clipboard[:ht][:journal] = true
  end
end

  

################################
######## IDENTIFIERS ###########
################################

to_field "lccn", extract_marc('010a')
to_field 'rptnum', extract_marc('088a')

oclc_pattern = /(?:oclc|ocolc|ocm|ocn)(\d+)/
to_field 'oclc' do |record, acc|
  oh35az_spec = Traject::MarcExtractor.cached('035az', :separator=>nil)
  oh35az_spec.extract(record).each do |d|
    if m = oclc_pattern.match(d)
      acc << m[1]
    end
  end
end

sdr_pattern = /^sdr-/
to_field 'sdrnum' do |record, acc|
  oh35a_spec = Traject::MarcExtractor.cached('035a')
  acc.concat oh35a_spec.extract(record).grep(sdr_pattern)
end



to_field 'isbn' do |record, acc|
  isbn_spec = Traject::MarcExtractor.cached('020az', :separator=>nil) # 
  vals = []
  isbn_spec.extract(record).each do |v|
    std = StdNum::ISBN.allNormalizedValues(v)
    if std.size > 0
      vals.concat std
    else
      vals << v
    end
  end
  vals.uniq! # If it already has both a 10 and a 13, each will have generated the other
  acc.concat vals
end

to_field 'issn', extract_marc('022a:022l:022m:022y:022z:247x')
to_field 'isn_related', extract_marc("400x:410x:411x:440x:490x:500x:510x:534xz:556z:581z:700x:710x:711x:730x:760x:762x:765xz:767xz:770xz:772x:773xz:774xz:775xz:776xz:777x:780xz:785xz:786xz:787xz")
to_field 'callnumber', extract_marc('050ab:090ab')
to_field 'callnoletters', extract_marc('050ab:090ab', :first=>true)
to_field 'sudoc', extract_marc('086az')

################################
######### AUTHOR FIELDS ########
################################

to_field 'mainauthor', extract_marc('100abcd:110abcd:111abc')
to_field 'author', extract_marc("100abcd:110abcd:111abc:700abcd:710abcd:711abc")
to_field 'author2', extract_marc("110ab:111ab:700abcd:710ab:711ab")
to_field "authorSort", extract_marc("100abcd:110abcd:111abc:110ab:700abcd:710ab:711ab", :first=>true)
to_field "author_top", extract_marc("100abcdefgjklnpqtu0:110abcdefgklnptu04:111acdefgjklnpqtu04:700abcdejqux034:710abcdeux034:711acdegjnqux034:720a:765a:767a:770a:772a:774a:775a:776a:777a:780a:785a:786a:787a:245c")
to_field "author_rest", extract_marc("505r")


################################
########## TITLES ##############
################################

# For titles, we want with and without
to_field 'title',     extract_with_and_without_filing_characters('245abdefghknp', :trim_punctuation => true)
to_field 'title_a',   extract_with_and_without_filing_characters('245a', :trim_punctuation => true)
to_field 'title_ab',  extract_with_and_without_filing_characters('245ab', :trim_punctuation => true)
to_field 'title_c',   extract_marc('245c')
to_field 'vtitle',    extract_marc('245abdefghknp', :alternate_script=>:only)
to_field 'title',     extract_marc('245')

# Sortable title
to_field "titleSort", marc_sortable_title


to_field "title_top", extract_marc("240adfghklmnoprs0:245abfghknps:247abfghknps:111acdefgjklnpqtu04:130adfghklmnoprst0")
to_field "title_rest", extract_marc("210ab:222ab:242abhnpy:243adfghklmnoprs:246abdenp:247abdenp:700fghjklmnoprstx03:710fghklmnoprstx03:711acdefghjklnpqstux034:730adfghklmnoprstx03:740ahnp:765st:767st:770st:772st:773st:775st:776st:777st:780st:785st:786st:787st:830adfghklmnoprstv:440anpvx:490avx:505t")
to_field "series", extract_marc("440ap:800abcdfpqt:830ap")
to_field "series2", extract_marc("490a")

# Serial titles count on the format alreayd being set and having the string 'Serial' in it.

to_field "serialTitle" do |r, acc, context|
  if context.clipboard[:ht][:journal]
    extract_with_and_without_filing_characters('245abdefghknp', :trim_punctuation => true).call(r, acc, context)
  end
end

to_field('serialTitle_ab') do |r, acc, context|
  if context.clipboard[:ht][:journal]
    extract_with_and_without_filing_characters('245ab', :trim_punctuation => true).call(r, acc, context)
  end
end  

to_field('serialTitle_a') do |r, acc, context|
  if context.clipboard[:ht][:journal]
    extract_with_and_without_filing_characters('245a', :trim_punctuation => true).call(r, acc, context)
  end
end  
  
to_field('serialTitle_rest') do |r, acc, context|
  if context.clipboard[:ht][:journal]
    extract_with_and_without_filing_characters(%w[
      130adfgklmnoprst
      210ab
      222ab
      240adfgklmnprs
      246abdenp
      247abdenp
      730anp
      740anp
      765st
      767st
      770st
      772st
      775st
      776st
      777st
      780st
      785st
      786st
      787st  
    ], :trim_punctuation => true).call(r, acc, context)
  end
end  



################################
######## SUBJECT / TOPIC  ######
################################

# We get the full topic (LCSH)...

to_field "topic", extract_marc(%w(
600abcdefghjklmnopqrstuvxyz
610abcdefghklmnoprstuvxyz
611acdefghjklnpqstuvxyz
630adefghklmnoprstvxyz
648avxyz
650abcdevxyz
651aevxyz
654abevyz
655abvxyz
656akvxyz
657avxyz
658ab
662abcdefgh
690abcdevxyz
), :trim_punctuation=>true)

#...and just the subfield 'a's

to_field "topic", extract_marc(%w(
600a
610a
611a
630a
648a
650a
651a
653a
654a
655a
656a
657a
658a
690a 
), :trim_punctuation=>true)

###############################
#### Genre / geography / dates
###############################

to_field "genre", extract_marc('655ab')


# Look into using Traject default geo field
to_field "geographic" do |record, acc|
  marc_geo_map = Traject::TranslationMap.new("marc_geographic")
  extractor_043a      = MarcExtractor.cached("043a", :seperator => nil)
  acc.concat(
    extractor_043a.extract(record).collect do |code|
      # remove any trailing hyphens, then map
      marc_geo_map[code.gsub(/\-+\Z/, '')]
    end.compact
  )
end

to_field 'era', extract_marc("600y:610y:611y:630y:650y:651y:654y:655y:656y:657y:690z:691y:692z:694z:695z:696z:697z:698z:699z")

# country from the 008; need processing until I fix the AlephSequential reader

to_field "country_of_pub" do |r, acc|
  country_map = Traject::TranslationMap.new("ht/country_map")
  if r['008']
    [r['008'].value[15..17], r['008'].value[17..17]].each do |s|
      country = country_map[s.gsub(/[^a-z]/, '')]
      acc << country if country
    end
  end
end

# Also add the 752ab  
to_field "country_of_pub", extract_marc('752ab')

# Deal with the dates

# First, find the date and put it into context.clipboard[:ht_date] for later use
each_record extract_date_into_context

# Now use that value
to_field "publishDate" do |record, acc, context|
  if context.clipboard[:ht][:date]
    acc << context.clipboard[:ht][:date] 
  else
    logger.debug "No valid date: #{record['001'].value}"
  end
end

to_field 'publishDateRange' do |rec, acc, context|
   dr = HathiTrust::Traject::Macros::HTMacros.compute_date_range(context.clipboard[:ht][:date])
   acc << dr if dr
 end


################################
########### MISC ###############
################################

to_field "publisher", extract_marc('260b:264|*1|:533c')
to_field "edition", extract_marc('250a')

to_field 'language', marc_languages("008[35-37]:041a:041d:041e:041j")
to_field 'language008', extract_marc('008[35-37]')

#####################################
############ HATHITRUST STUFF #######
#####################################
#


# Start off by building up a data structure representing all the 974s
# and stick it in ht_fields. Also, query the database for the print
# holdings along the way with #fill_print_holdings!

each_record do |r, context|
  
  itemset = HathiTrust::Traject::ItemSet.new
  
  r.each_by_tag('974') do |f|
    itemset.add HathiTrust::Traject::Item.new_from_974(f)
  end
  
  if itemset.size == 0
    context.skip!("No 974s in record  #{r['001']}")
  else
    context.clipboard[:ht][:items] = itemset
  end
    
end

unless ENV['SKIP_PH']
  each_record do |r, context|
    context.clipboard[:ht][:items].fill_print_holdings!
  end
end


# make use of the HathiTrust::ItemSet object stuffed into
# [:ht][:items] to pull out all the other stuff we need.

to_field 'ht_availability' do |record, acc, context|
  acc.concat context.clipboard[:ht][:items].us_availability
end

to_field 'ht_availability_intl' do |record, acc, context|
  acc.concat context.clipboard[:ht][:items].intl_availability
end

to_field 'ht_count' do |record, acc, context|
  acc << context.clipboard[:ht][:items].size
end

to_field 'ht_heldby' do |record, acc, context|
  acc.concat context.clipboard[:ht][:items].print_holdings
end

to_field 'ht_id' do |record, acc, context|
  acc.concat context.clipboard[:ht][:items].ht_ids
end

to_field 'ht_id_display' do |record, acc, context|
  context.clipboard[:ht][:items].each do |item|
    acc << item.display_string
  end
end

to_field 'ht_id_update' do |record, acc, context|
  acc.concat context.clipboard[:ht][:items].last_update_dates
end

to_field 'ht_json' do |record, acc, context|
  acc << context.clipboard[:ht][:items].to_json
end

to_field 'ht_rightscode' do |record, acc, context|
  acc.concat context.clipboard[:ht][:items].rights_list
end


to_field 'ht_searchonly' do |record, acc, context|
  acc << context.clipboard[:ht][:items].us_fulltext? ? 'false' : 'true'
end

to_field 'ht_searchonly_intl' do |record, acc, context|
  acc << context.clipboard[:ht][:items].intl_fulltext? ? 'false' : 'true'
end

to_field 'htsource' do |record, acc, context|
  acc.concat context.clipboard[:ht][:items].sources
end
