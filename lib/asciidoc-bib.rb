# asciidoc-bib.rb
#
# Copyright (c) Peter Lane, 2012.
# Released under Open Works License, 0.9.2

require 'asciidoc-bib/extensions'
require 'bibtex'

module AsciidocBib

  # Locate a bibliography file to read in given dir
  def find_bibliography dir
    begin
      candidates = Dir.glob("#{dir}/*.bib")
      if candidates.empty?
        return ""
      else
        return candidates.first
      end
    rescue # catch all errors, and return empty string
      return ""
    end
  end

  # Read in a given bibliography file and return a biblio instance
  def read_bibliography filename
    BibTeX.open(filename)
  end

	# Read given text to locate cites, return list of used references
	def read_citations filename
		puts "Reading file: #{filename}"
		cites_used = []
    files_to_process = [filename]
    files_done = []

    begin
      files_done << files_to_process.first
	  	File.new(files_to_process.shift).each_line do |line|
        if line.include?("include::")
          line.split("include::").drop(1).each do |filetxt|
            file = File.expand_path(filetxt.partition(/\s|\[/).first)
            files_to_process << file unless files_done.include?(file)
          end
        else
		  	  extract_cites(line).each do |cite|
			  	  unless cites_used.include? cite
				  	  cites_used << cite
				    end
  			  end
        end
		  end
    end until files_to_process.empty?

		return cites_used
	end

	# Read given text to add cites and biblio to a new file
	def add_citations(filename, cites_used, biblio)
    files_to_process = [filename]
    files_done = []

    begin
      curr_file = files_to_process.shift
      files_done << curr_file

      ref_filename = add_ref(curr_file)
		  puts "Writing file:	#{ref_filename}"
  		output = File.new(ref_filename, "w")

      File.new(curr_file).each_line do |line|
        if line.include?("include::")
          line.split("include::").drop(1).each do |filetxt|
            ifile = filetxt.partition(/\s|\[/).first
            file = File.expand_path(ifile)
            files_to_process << file unless files_done.include?(file)
            # make sure included file points to the -ref version
            line.gsub!("include::#{ifile}", "include::#{add_ref(file)}")
          end
          output.puts line
  			elsif line.strip == "[bibliography]"
	  			cites_used.sort_by do |ref|
		  			unless biblio[ref].nil?
              # extract the reference
			  			author_chicago(biblio[ref].author)
				  	else 
  						[ref]
	  				end
		  		end.each do |ref|
			  		output.puts get_reference(biblio, ref).gsub("{","").gsub("}","")
  					output.puts
	  			end
		  	else
					md = CITATION_FULL.match(line)
					while md
						cite_refs, cite_pages = extract_refs_pages md[4]
						# replace text on line
						line.gsub!(md[0],
											 get_citation(biblio, md[1], md[3], cite_refs, cite_pages)
											)
						# look for next citation on line
						md = CITATION_FULL.match(md.post_match)
					end

	  			output.puts line
		  	end
  		end

  		output.close
    end until files_to_process.empty?
  end
end
