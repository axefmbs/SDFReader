package require sqlite3

namespace eval SQL \
{
	variable ids {} ; # indices for records found
	variable result
	array set result {}
} ; # end namespace

proc SQL::cleanup {} {
	variable ids {}
	variable result
	array unset result
	array set result {}
}

proc SQL::create_table { cols } {
	set problem [ catch {
		db eval "CREATE TABLE sdfparser_tab(sdfparser_id INTEGER PRIMARY KEY, $cols)"
	} zonk ]

	if { $problem } {
		DEBUG::put 1 " inside '[info level 0]' >>  problem = $problem; zonk = $zonk"
		set answer [tk_messageBox -icon error -type yesno\
		-message "There was an error when creating database\n\
		  Do you want to see the error message?"]
			if { $answer } {
				tk_messageBox -icon info -type ok\
				-message "$zonk"
			} ; # end if
	} ; # end if
} ; # end proc

proc SQL::insert_data {cols vals} {
	set problem [ catch {
		db eval "INSERT INTO sdfparser_tab ($cols) VALUES ($vals)"
	} zonk ]

	if { $problem } \
	{
		set answer [tk_messageBox -icon error -type yesno\
		-message "There was an error when writing to database.\n\
		  Do you want to see the error message?"]
		  if { $answer } {
				tk_messageBox -icon info -type ok\
				-message "$zonk"
		  } ; # end if

	} ; # end if
}
proc SQL::get_fields { filename } \
{
	sqlite3 db $filename
	DEBUG::put 9 "opening database $filename"
	db eval {SELECT * FROM sdfparser_tab WHERE sdfparser_id=1;} result {
		DEBUG::put 10 "fields: $result(*)"
		set SDF::fields  $result(*)
	}
	db close

} ; # end proc

proc SQL::get_ids { filename query } \
{
	sqlite3 db $filename
	set SQL::ids [db eval $query]
	db close
	#return $ids

} ; # end proc

proc SQL::get_record { filename id } \
{
	sqlite3 db $filename
	#set record [db eval "SELECT * FROM sdfparser_tab WHERE sdfparser_id=$id ;"]
	db eval "SELECT * FROM sdfparser_tab WHERE sdfparser_id=$id ;" SQL::result {
		#parray  SQL::result
	}
	db close
	#return $record
} ; # end proc

namespace eval DEBUG {
	variable flag 0
	variable types { 2 7  10 }
} ; # end namespace


proc DEBUG::put {type text} {
	variable types
	variable flag
	if { $flag } {
		if { [lsearch $types $type] >= 0 } { puts "debug $type: $text" }
		# after 200
	} ; # end if
}

namespace eval SDF {

	variable filetypes_sdf \
	{
		{{MOL, MDL, SDF}	{.mol .MOL .mdl .MDL .sdf .SDF} }
		{{All Files}		*		}
	}

	variable filetypes_db {
		{{DB, SQLITE}		{.db .DB .sqlite .SQLITE} }
	}

	variable status1 "SDFreader ver 0.1 by Witek Mozga"
	variable status2 ""
	variable stop_task 0
	variable line_number 0
	variable record_number 0
	variable current_record 0
	variable sql_ready 0
	variable datamode ""
	variable current_mol {}
	variable filename ""
	variable sqlite_filename ""
	variable fields {sdfparser_moldata } ; # list to store fileds name, these two are added despite others
	variable database ; # keeps records to be inserted into sqlite
	array set database {}

} ; # end namespace


proc SDF::open_file { filetype } {
	# DEBUG::put 1 "filetype: $filetype"
	#variable filetypes_sdf
	variable filename
	variable status1

	set filename [tk_getOpenFile -filetypes $filetype -title "Open SDF or MOL file"];
	if {$filename != ""} {
		DEBUG::put 2 " opened:  $filename "
		set status1 "[file tail $filename]"
		set FILE [open $filename]
		return $FILE
	}
}


proc SDF::extract_mol { FILE } {
	variable line_number
	variable current_mol
	variable database
	variable record_number

	set current_mol {}

	while { 1 } {
			if { [gets $FILE line] >= 0 } {
				incr line_number
				lappend current_mol $line
				if { $line == "M  END" } {
					break
				} ; # end if
			} else {
				DEBUG::put 9 "inside '[info level 0]' >> end of file at line $line_number"
				return "eof"
			} ; # end else
	} ; # end while
	DEBUG::put 9 "current_mol: [join $current_mol "\n"] "
	set database(sdfparser_moldata-$record_number) [join $current_mol "\n"]
	DEBUG::put 9 "record: $record_number "
} ; # end proc

proc SDF::extract_data { FILE } {
	variable line_number
	variable database
	variable filename
	variable record_number
	variable current_mol
	variable fields

	while { 1 } {
		# finding fields (dataheaders)
		if { [gets $FILE line] >= 0 } {
			incr line_number
			if { [string range $line 0 3] == "$$$$" } {
					DEBUG::put 12 "end of record $record_number"
					break
			} else {
					if { [string range $line 0 0] != ">" } {
						tk_messageBox -icon warning -type ok\
						-message "$filename seems to be corupted at line $line_number:\n\
									There should be '>' here "
						DEBUG::put 1 "inside '[info level 0]' >> there should be '>' here \
								instead of [string range $line 0 0] at line $line_number"
						return "eof"
					} else {
							set open_tag [string first "<" $line]
							if { $open_tag < 0 } {
								tk_messageBox -icon warning -type ok\
								-message "$filename seems to be corupted at line $line_number:\n\
											I can`t find opening '<' "
								DEBUG::put 1 " inside '[info level 0]' >>  can`t find opening '<' at line $line_number"
								return "eof"
							}
							set close_tag [string last ">" $line]
							if { $close_tag <= 0 } {
								tk_messageBox -icon warning -type ok\
								-message "$filename seems to be corupted at line $line_number:\n\
										 I can`t find closing '>'"
								DEBUG::put 1 " inside '[info level 0]' >>  can`t find closing '>' at line $line_number"
								return "eof"
							}

							incr open_tag
							incr close_tag -1
							set field_name [string range $line $open_tag $close_tag]
							set field_name [string map {"'" "_" "\"" "_" "-" "_" " " "_" "+" "_"} $field_name]
							# DEBUG::put 1 "field name: $field_name"
							if { [lsearch $fields $field_name] < 0 } {
								DEBUG::put 3 "adding field name $field_name to give fields: $fields"
								lappend fields $field_name
							}; # end if
					} ; # end else

					# finding data corresponding to dataheader just read
					set data_item {}
					while { 1 } {
						if { [gets $FILE line] >=0 } {
							incr line_number
							if { $line != "" } {
								lappend data_item $line
							} else {
								break
							} ; # end else
						} else {
							DEBUG::put 2 " inside '[info level 0]' >>  Unexpected end of file at line $line_number"
							return "eof"
						} ; # end else
					} ; # end while

					set database($field_name-$record_number) [join $data_item " "]
					DEBUG::put 1 "value: $field_name-$record_number -> $database($field_name-$record_number)"

			} ; # end else
		} else {
			DEBUG::put 2 " inside '[info level 0]' >>  Unexpected end of file at line $line_number"
			return "eof"
		} ; # end else

	} ; # end while

} ; # end proc


proc SDF::analyze_sdf { FILE } {

	variable record_number 1
	variable current_record
	variable status2
	variable stop_task

	sdfreadergui::menu_off

	while { 1 } {

		# extracting MOL file
		if { [extract_mol $FILE] == "eof" } {
			break
		} ; # end if

		# extracting data
		### below 'break' was commented in order to parse MOLfiles too
		if { [extract_data $FILE] == "eof" } {
			#break
		} ; # end if

		if { $stop_task } \
		{
			set stop_task 0
			break
		} ; # end if

		set status2 "analyzing record: $record_number"
		update

		if { $current_record == 0 } \
		{
			SDF::goto_record 1
		} ; # end if

		incr record_number
	} ; #endwhile

	incr record_number -1
	sdfreadergui::menu_on

}

proc SDF::populate_database {  } {
	variable filename
	variable filetypes_db
	variable database
	variable fields
	variable record_number
	variable status2
	variable stop_task

	set dir [file dirname $filename]
	set name [file tail  $filename]
	set name [split $name "."]
	set name [lindex $name 0]
	set filename_s [tk_getSaveFile -filetypes $filetypes_db -title "Save database in sqlite format"\
	-defaultextension .sqlite  -initialdir $dir -initialfile $name.sqlite]
	DEBUG::put 1 "filename to save: $filename_s"
	if { $filename_s != "" } {
		set dir [file dirname $filename_s]
		if { [file writable $dir] } {
			if {[info commands db] != ""} {
				# DEBUG::put 2 "closing database"
				db close
			}
			if { [file exists $filename_s] } {
				file delete $filename_s
			} ; # end if
			sqlite3 db $filename_s
			set cols [join $fields ", "]
			DEBUG::put 3 "columns to be created: $cols"
			db timeout 1000
			db transaction {
				SQL::create_table $cols
				for {set i 1} {$i <= $record_number } {incr i} {
					set status2 "writing record: $i"
					set col_list {}
					set val_list {}
					if { $stop_task } \
					{
						set stop_task 0
						break
					} ; # end if
					foreach x $fields {
						# DEBUG::put 1 $x
						if { [info exist database($x-$i)] } {
							set val \"$database($x-$i)\"
							DEBUG::put 1 "key - value: $x -> $val"
							lappend col_list $x
							lappend val_list $val
						} ; # end if

					} ; # end foreach
					DEBUG::put 1 "data to insert: $col_list -> $val_list"
					set cols [join $col_list ", "]
					set vals [join $val_list ", "]
					SQL::insert_data $cols $vals
					update
				} ; # end for
			}; # end transaction
			db close
			incr i -1
			set status2 "$i records saved to [file tail $filename_s]"
			set SDF::sqlite_filename $filename_s
		} else {
			tk_messageBox -icon warning -type ok\
				-message "Permission denied when writing to $dir"
			DEBUG::put 1 "inside '[info level 0]' >>  Cannot write to $dir"
			populate_database
		}

	} ; # end if

} ; # end proc


proc SDF::cleanup {} {
	variable status2 ""
	#variable status1 "SDFreader ver 0.1"
	variable current_record 0
	variable line_number 0
	variable record_number 0
	variable current_mol {}
	variable fields { sdfparser_moldata }
	variable database
	variable sql_ready 0
	variable stop_task 0
	variable sqlite_filename ""
	variable datamode ""
	array unset database
	array set database {}
	MOL::clear_canvas
	SQL::cleanup
	$sdfreadergui::BASE.text_data delete 1.0 end
}

proc SDF::open_SDF {} {
	variable filetypes_sdf
	variable datamode

	set FILE [SDF::open_file $filetypes_sdf ]
	if { $FILE != "" } \
	{
		SDF::cleanup
		sdfreadergui::hide_search_popup
		set datamode "SDF"
		SDF::analyze_sdf $FILE
		SDF::show_data
		# SDF::populate_database
	} ; # end if
}

proc SDF::goto_record  { n } \
{
	variable datamode
	if { $datamode == "SDF" } \
	{
		SDF::goto_sdf_record $n
	} ; # end if

	if { $datamode == "SQL" } \
	{
		DEBUG::put 10 "inside if in goto_record"
		SDF::goto_sql_record $n
	} ; # end if
} ; # end proc

proc SDF::goto_sql_record { n } \
{
	variable record_number
	variable current_record
	variable fields

	DEBUG::put 10 "inside goto_sql_record n = $n rec_no = $record_number"

	$sdfreadergui::BASE.text_data delete 1.0 end

	if { $record_number > 0 } \
	{
		if { $n > $record_number } \
		{
			set n $record_number
		} ; # end if
		if { $n < 1 } \
		{
			set n 1
		} ; # end if

		set id [expr {$n-1}]
		SQL::get_record $SDF::sqlite_filename [lindex $SQL::ids $id]

		foreach x $fields \
		{
			if { $x != "sdfparser_moldata" && [info exist SQL::result($x)] }\
			{
				$sdfreadergui::BASE.text_data insert end "$x:\t\t$SQL::result($x)\n"
				set current_record $n
			} ; # end if

		} ; # end foreach

		MOL::clear_canvas
		MOL::create_structure $SQL::result(sdfparser_moldata)

	} ; # end if
} ; # end proc

proc SDF::goto_sdf_record { n } \
{
	variable database
	variable record_number
	variable current_record
	variable fields

	$sdfreadergui::BASE.text_data delete 1.0 end

	if { $record_number > 0 } \
	{
		if { $n > $record_number } \
		{
			set n $record_number
		} ; # end if
		if { $n < 1 } \
		{
			set n 1
		} ; # end if

		foreach x $fields \
		{
			if { $x != "sdfparser_moldata" && [info exist database($x-$n)] }\
			{
				$sdfreadergui::BASE.text_data insert end "$x:\t\t$database($x-$n)\n"
				set current_record $n
			} ; # end if

		} ; # end foreach

		MOL::clear_canvas
		MOL::create_structure $database(sdfparser_moldata-$n)

	} ; # end if

} ; # enjd proc

proc SDF::show_data {  } \
{
	variable record_number
	variable status2
	if { $record_number > 0 } \
	{
		set status2 "$record_number records found"

		if {[$sdfreadergui::entry_record get] == 0 || $SDF::datamode == "SQL" } \
		{
			goto_record 1
		}
	} ; # end if
} ; # end proc

proc SDF::save_db {  } \
{
	variable record_number
	variable sql_ready
	if { $record_number > 0 } \
	{
		sdfreadergui::menu_off
		SDF::populate_database
		sdfreadergui::menu_on
		set sql_ready 1
	} ; # end if
} ; # end proc

proc SDF::open_db {  } \
{
	variable filetypes_db
	variable filename
	variable status1
	variable datamode

	set filename [tk_getOpenFile -filetypes $filetypes_db  -title "Open sqlite database"];
	if {$filename != ""} \
	{

		SDF::cleanup
		sdfreadergui::hide_search_popup
		DEBUG::put 2 " opened:  $filename "
		set status1 "[file tail $filename]"
		set status2 "Ready to search"
		set SDF::sqlite_filename $filename
		set problem [ catch {
					SQL::get_fields $filename
					SQL::get_ids $filename " SELECT sdfparser_id FROM sdfparser_tab "
					if { $SQL::ids != "" } \
					{
						set SDF::datamode SQL
						set SDF::sql_ready 1
						set SDF::record_number [llength $SQL::ids]
						DEBUG::put 10 "found  [llength $SQL::ids] records"
						SDF::show_data
					} else \
					{
						MOL::clear_canvas
						$sdfreadergui::BASE.text_data delete 1.0 end
						set SDF::record_number 0
						tk_messageBox -icon info -type ok \
						-message "No substances in database"
					} ; # end else
			} zonk ]

		if { $problem } \
		{
			tk_messageBox -icon error -type ok\
			-message "There was an error when reading database:\n$zonk"
			return
		} ; # end if

	}

} ; # end proc




DEBUG::put 2 "fields in the database: $SDF::fields"
DEBUG::put 2 "records in database: $SDF::record_number "

# foreach x [array names database [lindex $fields 5].*]  {
	# DEBUG::put 1 "record: $x -> $database($x)"
# } ; # end foreach
#
# foreach x [array names database [lindex $fields 1].*]  {
	# DEBUG::put 1 "record: $x -> $database($x)"
# } ; # end foreach
