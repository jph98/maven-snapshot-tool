#!/usr/bin/env ruby

require 'rexml/document'
require 'fileutils'

include REXML

# Simple Maven POM helper to replace versions in the pom.xml
class Ph

	SNAPSHOT_KEY = "s"
	ALL_KEY = "a"

	SNAPSHOT_STATUS = "SNAPSHOT"

	UNSNAPSHOT = :unsnapshot
	SNAPSHOT = :snapshot

	def initialize(should_write)
		@should_write = should_write
	end

	def status(poms, secondary_command)
		
		msgs = []
		poms.each do |p|			
			artifact, version = find_all_artifact_info(p)
			if !artifact.nil?

				if secondary_command.eql? SNAPSHOT_KEY and version.include? SNAPSHOT_STATUS
					msgs << "\tPOM: #{artifact} - #{version} - #{p}"
				elsif secondary_command.eql? ALL_KEY
					msgs << "\tPOM: #{artifact} - #{version} - #{p}"
				end
			end
		end

		if msgs.size.eql? 0 
			puts "\tNone"
		else
			msgs.sort.each do |m|
				puts "#{m}"
			end
		end
	end

	def find_poms()

		return poms = Dir.glob("**/pom.xml")		
	end

	def find_all_artifact_info(pom_file)
		
		xmldoc = Document.new File.new(pom_file)
		
		artifact_name = get_artifact_name(xmldoc)
		version = get_version(xmldoc)
		
		if !artifact_name.empty? and !version.empty?			
			snapshot = version.include? SNAPSHOT_KEY
			return artifact_name, version
		end		
	end

	def get_version(xmldoc)

		version = ""
		xmldoc.elements.each("project/version") do |pa|
			version = pa.text			
		end
		return version
	end

	def unsnapshot(mode, poms, artifact_name)

		# This will change the top level definition
		poms.each do |p|			
			replace_project_reference(PH::UNSNAPSHOT, p, artifact_name)		
		end	

		# This will change all references found in other pom files
		poms.each do |p|
			artifact, version_text = replace_dependency_references(PH::UNSNAPSHOT, p, artifact_name)
		end
	end

	def change_project_references(mode, pom_file, artifact_name, version_and_branch_name)
		
		xmldoc = Document.new File.new(pom_file)
		
		name = get_artifact_name(xmldoc)

		if mode.eql? Ph::UNSNAPSHOT and artifact_name.eql? name
			puts "PROJECT POM version for #{name} in #{pom_file}"
			unsnapshot_project_version(pom_file, xmldoc)
			return artifact_name
		elsif mode.eql? Ph::SNAPSHOT and artifact_name.eql? name
			puts "PROJECT POM version for #{name} in #{pom_file}"
			snapshot_project_version(pom_file, xmldoc, version_and_branch_name)
			return artifact_name
		end
	end

	def change_dependency_references(mode, pom_file, artifact_name, version_and_branch_name)

		xmldoc = Document.new File.new(pom_file)

		if mode.eql? Ph::UNSNAPSHOT		
			unsnapshot_dependency_version(pom_file, xmldoc, artifact_name)
		elsif mode.eql? Ph::SNAPSHOT
			snapshot_dependency_version(pom_file, xmldoc, artifact_name, version_and_branch_name)
		end
		
	end

	def unsnapshot_project_version(pom_file, xmldoc)
		
		xmldoc.elements.each("project/version") do |pa|
			
			xml_version = pa.text
			if xml_version.include? SNAPSHOT_STATUS

				version = xml_version.match(/([0-9\.]*)-/)[1]
				pa.text = version
				puts "\tPROJECT POM: #{xml_version} to #{version} for #{pom_file}"
			end			
		end

		write_doc(xmldoc)
	end

	def snapshot_project_version(pom_file, xmldoc, version_and_branch_name)
		
		xmldoc.elements.each("project/version") do |pa|
			
			xml_version = pa.text

			puts "Changing version: '#{xml_version}' from #{pa.text} to #{version_and_branch_name}"
			pa.text = version_and_branch_name
		end

		write_doc(xmldoc)
	end

	def get_artifact_name(xmldoc)

		artifact_name = ""
		xmldoc.elements.each("project/artifactId") do |pa|
			artifact_name = pa.text			
		end
		return artifact_name
	end

	def write_doc(xmldoc)

		if @should_write
			File.open(pom_file, "w") do |data|
				data << xmldoc
			end
		end
	end

	def unsnapshot_dependency_version(pom_file, xmldoc, artifact_name)
		
		# TODO: Ignore current file
		puts "Considering #{pom_file} for #{artifact_name}"

		xmldoc.elements.each("project/dependencies/dependency/version") do |pa|
			
			xml_version = pa.text
			
			puts "Version: '#{xml_version}' for #{pa.text}"

			if xml_version.include? SNAPSHOT_STATUS

				version = xml_version.match(/([0-9\.]*)-/)[1]
				pa.text = version
				puts "\tDEPENDENCY: #{xml_version} to #{version} for #{artifact_name} in file #{pom_file}"
			else 
				puts "no replace for dependency"
			end			

		end

		write_doc(xmldoc)
	end

	def snapshot_dependency_version(pom_file, xmldoc, artifact_name, snapshot_dependency_version)
		
		# TODO: Ignore current file
		puts "Considering #{pom_file} for #{artifact_name}"

		xmldoc.elements.each("project/dependencies/dependency/version") do |pa|
			
			xml_version = pa.text
			
			puts "Changing version: '#{xml_version}' from #{pa.text} to #{snapshot_dependency_version}"

			# TODO
			pa.text = snapshot_dependency_version

		end

		write_doc(xmldoc)
	end


	def change_references(mode, poms, artifact_name, version_and_branch_name)

		puts "#{mode} #{artifact_name} with #{version_and_branch_name}"

		# This will change the top level definition
		poms.each do |p|			
			change_project_references(mode, p, artifact_name, version_and_branch_name)
		end	

		# This will change all references found in other pom files
		poms.each do |p|
			artifact, version_text = change_dependency_references(mode, p, artifact_name, version_and_branch_name)
		end
	end

	def help()

		# Global help
		puts "Usage:\t#{File.basename($0)} status <a|s> or ALL:SNAPSHOT\n" + 		     
		     "\t#{File.basename($0)} unsnapshot <servicename>"
	end

end

# Init without writing changes
ph = Ph.new(false)

if ARGV.length > 0

	command = ARGV[0]	

	poms = ph.find_poms()

	if command.eql? "status"

		if ARGV.size.eql? 2 and !ARGV[1].nil?
			secondary_command = ARGV[1].downcase
			ph.status(poms, secondary_command)		
		else
			puts "Usage: #{File.basename($0)} status <#{Ph::SNAPSHOT_KEY}|#{Ph::ALL_KEY}>"
		end
	elsif command.eql? "unsnapshot"

		artifact_names = ARGV[1..ARGV.length()]
		artifact_names.each do |a|

			if !a.nil?
				ph.change_references(Ph::UNSNAPSHOT, poms, a)
			else
				puts "ERROR: Usage: #{File.basename($0)} unsnapshot <nameofservice>"
			end
		end
	elsif command.eql? "snapshot"

		artifactname = ARGV[1]		
		version_branch_name = ARGV[2]
		if !artifactname.nil? and !version_branch_name.nil?
			puts "Snapshot #{artifactname} with #{version_branch_name}"
			ph.change_references(Ph::SNAPSHOT, poms, artifactname, version_branch_name)
		else
			puts "ERROR: Usage: #{File.basename($0)} snapshot <nameofservice> <version_and_branch_name>"
		end
	else
		puts ph.help()
	end
else
	ph.help()
end	
