#!/usr/bin/env wish
# sdfreadergui.tcl --
#
# UI generated by GUI Builder Build 146 on 2009-07-27 14:49:33 from:
#    /media/KINGSTON/Tcl-Tk/SDFreader/SDFReader/sdfreadergui.ui
# This file is auto-generated.  Only the code within
#    '# BEGIN USER CODE'
#    '# END USER CODE'
# and code inside the callback subroutines will be round-tripped.
# The proc names 'ui' and 'init' are reserved.
#

package require Tk 8.4

# Declare the namespace for this dialog
namespace eval sdfreadergui {}

# Source the ui file, which must exist
set sdfreadergui::SCRIPTDIR [file dirname [info script]]
source [file join $sdfreadergui::SCRIPTDIR sdfreadergui_ui.tcl]

# BEGIN USER CODE

proc sdfreadergui::search_popup { value_list } \
{
	toplevel .query -width [winfo width .]

	label  .query.l  -text "Search for substances in which:" -font {Helvetica 12 bold }
	grid .query.l -row 1 -column 1 -columnspan 4

	ttk::combobox .query.combo1 -values $value_list -state readonly
	label .query.l1 -text " contains "
	entry .query.entry1 -background white
	ttk::combobox .query.logic1 -values { AND OR {AND NOT} {OR NOT}} -width 10  -state readonly
	.query.logic1 set AND

	grid .query.combo1 -row 2 -column 1 -sticky "nsew" -padx {5 0}
	grid .query.l1 -row 2 -column 2 -sticky "nsew"
	grid .query.entry1 -row 2 -column 3 -sticky "nsew"
	grid .query.logic1 -row 2 -column 4 -sticky "nsew"  -padx {0 5}

	ttk::combobox .query.combo2 -values $value_list -state readonly
	label .query.l2 -text " contains "
	entry .query.entry2  -background white
	ttk::combobox .query.logic2 -values { AND OR {AND NOT} {OR NOT}} -width 10 -state readonly
	.query.logic2 set AND

	grid .query.combo2 -row 3 -column 1 -sticky "nsew" -padx {5 0}
	grid .query.l2 -row 3 -column 2 -sticky "nsew"
	grid .query.entry2 -row 3 -column 3 -sticky "nsew"
	grid .query.logic2 -row 3 -column 4 -sticky "nsew"  -padx {0 5}

	ttk::combobox .query.combo3 -values $value_list -state readonly
	label .query.l3 -text " contains "
	entry .query.entry3 -background white
	button .query.b -text "Search" -command sdfreadergui::parse_query

	grid .query.combo3 -row 4 -column 1 -sticky "nsew" -pady {0 5} -padx {5 0}
	grid .query.l3 -row 4 -column 2 -sticky "nsew" -pady {0 5}
	grid .query.entry3 -row 4 -column 3 -sticky "nsew" -pady {0 5}
	grid .query.b -row 4 -column 4 -sticky "nsew" -pady {0 5}  -padx {0 5}

	grid columnconfigure .query 1 -weight 1
	grid columnconfigure .query 2 -weight 0
	grid columnconfigure .query 3 -weight 1
	grid columnconfigure .query 4 -weight 0


	wm withdraw .query
	update

	set x [expr {[winfo x .]}]
	set y [expr {[winfo y .]+ 5 + [winfo height .] }]
	wm geometry  .query +$x+$y
	wm transient .query .
	wm title     .query "Search"

	#wm deiconify .query
} ; # end proc

proc sdfreadergui::parse_query {  } \
{
	DEBUG::put 1 "inside parse_query"
	set query {SELECT sdfparser_id FROM sdfparser_tab WHERE }

	set c1 [.query.combo1 get]
	set t1 [.query.entry1 get]


	if { $c1 != "" && $t1 != "" } \
	{
		append query " $c1 LIKE '%$t1%' "
	} ; # end if

	set c2 [.query.combo2 get]
	set t2 [.query.entry2 get]

	if { $c2 != "" && $t2 != "" } \
	{
		if { $c1 != "" && $t1 != ""  } \
		{
			append query " [.query.logic1 get] "
		} ; # end if
		append query " $c2 LIKE '%$t2%' "
	} ; # end if

	set c3 [.query.combo3 get]
	set t3 [.query.entry3 get]

	if { $c3 != "" && $t3 != "" } \
	{
		if { $c2 != "" && $t2 != ""  } \
		{
			append query " [.query.logic2 get] "
		} elseif { $c1 != "" && $t1 != ""  } \
		{
			append query " [.query.logic1 get] "
		} ; # end if
		append query " $c3 LIKE '%$t3%' "
	} ; # end if

	append query ";"
	DEBUG::put 10 "Query: $query"

	catch {SQL::get_ids $SDF::sqlite_filename $query}

	DEBUG::put 10 "ids: $SQL::ids"
	if { $SQL::ids != "" } \
	{
		set SDF::datamode SQL
		set SDF::record_number [llength $SQL::ids]
		DEBUG::put 10 "found  [llength $SQL::ids] records"
		SDF::show_data
	} else \
	{
		MOL::clear_canvas
		$sdfreadergui::BASE.text_data delete 1.0 end
		set SDF::record_number 0
		tk_messageBox -icon info -type ok \
		-message "No substances"
	} ; # end else

} ; # end proc

proc sdfreadergui::hide_search_popup {  } \
{
	catch  {destroy .query}
	update
} ; # end proc

proc sdfreadergui::show_search_popup {  } \
{
	sdfreadergui::hide_search_popup

	set idx  [lsearch -exact $SDF::fields sdfparser_moldata]
	set temp [lreplace $SDF::fields $idx $idx]

	set idx  [lsearch -exact $temp sdfparser_id]
	set temp [lreplace $temp $idx $idx]

	lappend temp {}

	set temp [lsort $temp]

	sdfreadergui::search_popup $temp
	update
	wm deiconify .query
	#wm geometry  .query =[winfo width .]x[winfo height .query]
} ; # end proc

proc sdfreadergui::menu_on {  } \
{
	bind . <Control-o> {SDF::open_SDF}
	bind . <Control-d> {SDF::open_db}
	bind . <Control-s> {SDF::save_db}
	#puts [$sdfreadergui::menuitem1 entryconfigure ]
	$sdfreadergui::menu entryconfigure 1 -state normal
	$sdfreadergui::_button_stop configure -state disable
} ; # end proc

proc sdfreadergui::menu_off {  } \
{
	bind . <Control-o> {}
	bind . <Control-d> {}
	bind . <Control-s> {}
	$sdfreadergui::menu entryconfigure 1 -state disable
	$sdfreadergui::_button_stop configure -state normal
} ; # end proc

proc sdfreadergui::setup_gui {  } \
{
	wm title $sdfreadergui::ROOT "SDFReader"
	#set x [expr {([winfo screenwidth .]-[winfo width .])/2}]
	#set y [expr {([winfo screenheight .]-[winfo height .])/2}]
	#wm geometry  $sdfreadergui::ROOT +$x+$y
	wm geometry  $sdfreadergui::ROOT +300+300

	sdfreadergui::menu_on

	$sdfreadergui::mol_canvas bind bond <Button-1> \
	{
		MOL::find_nearest %x %y
	}

	$sdfreadergui::mol_canvas bind carbon_atom <Button-1> \
	{
		MOL::find_nearest %x %y
	}

	$sdfreadergui::mol_canvas bind atom_symbol <Button-1> \
	{
		 #set MOL::xc %x; set MOL::yc %y; \
		 #set MOL::nearest [$sdfreadergui::mol_canvas find closest $MOL::xc $MOL::yc]; \
		 #puts "$MOL::nearest atom @ $MOL::xc $MOL::yc"
		 MOL::find_nearest %x %y
	}

	 MOL::assign_canvas $sdfreadergui::mol_canvas
	 $sdfreadergui::mol_canvas  bind bond <B1-Motion>  {MOL::move  %x %y}
	 $sdfreadergui::mol_canvas  bind atom_symbol <B1-Motion>  {MOL::move  %x %y}
	 $sdfreadergui::mol_canvas  bind carbon_atom <B1-Motion>  {MOL::move  %x %y}
	 bind $sdfreadergui::mol_canvas  <Configure> {+MOL::rescale %w %h}

 }
# END USER CODE

# BEGIN CALLBACK CODE
# ONLY EDIT CODE INSIDE THE PROCS.

# sdfreadergui::_button_go_command --
#
# Callback to handle _button_go widget option -command
#
# ARGS:
#    <NONE>
#
proc sdfreadergui::_button_go_command args {
	 DEBUG::put 5 "[$sdfreadergui::entry_record get]"
	 SDF::goto_record [$sdfreadergui::entry_record get]
}

# sdfreadergui::_button_next_command --
#
# Callback to handle _button_next widget option -command
#
# ARGS:
#    <NONE>
#
proc sdfreadergui::_button_next_command args {
	 DEBUG::put 5 "$SDF::current_record"
	 SDF::goto_record [expr { $SDF::current_record + 1 }]
}

# sdfreadergui::_button_prev_command --
#
# Callback to handle _button_prev widget option -command
#
# ARGS:
#    <NONE>
#
proc sdfreadergui::_button_prev_command args {
	DEBUG::put 5 "$SDF::current_record"
	SDF::goto_record [expr { $SDF::current_record - 1 }]
}

# sdfreadergui::_button_search_command --
#
# Callback to handle _button_search widget option -command
#
# ARGS:
#    <NONE>
#
proc sdfreadergui::_button_search_command args {
	if { $SDF::sql_ready } \
	{
		sdfreadergui::show_search_popup
	} else \
	{
		set answer [tk_messageBox -icon info -type ok \
		-message "In order to search you need to\n\
					open SDF file and save it\n\
					as an sqlite database or\n\
					open a previously saved one.\n\ "]

		#if { $answer && $SDF::record_number > 0 } \
		#{
			#SDF::save_db
		#}
		#if { $answer && $SDF::record_number <= 0 } \
		#{
			#SDF::open_db
		#} ; # end elseif
	} ; # end else
}

# sdfreadergui::_button_stop_command --
#
# Callback to handle _button_stop widget option -command
#
# ARGS:
#    <NONE>
#
proc sdfreadergui::_button_stop_command args {
	set SDF::stop_task 1
}

# sdfreadergui::entry_record_invalidcommand --
#
# Callback to handle entry_record widget option -invalidcommand
#
# ARGS:
#    <NONE>
#
proc sdfreadergui::entry_record_invalidcommand args {}

# sdfreadergui::entry_record_validatecommand --
#
# Callback to handle entry_record widget option -validatecommand
#
# ARGS:
#    <NONE>
#
proc sdfreadergui::entry_record_validatecommand args {}

# sdfreadergui::entry_record_xscrollcommand --
#
# Callback to handle entry_record widget option -xscrollcommand
#
# ARGS:
#    <NONE>
#
proc sdfreadergui::entry_record_xscrollcommand args {}

# sdfreadergui::mol_canvas_xscrollcommand --
#
# Callback to handle mol_canvas widget option -xscrollcommand
#
# ARGS:
#    <NONE>
#
proc sdfreadergui::mol_canvas_xscrollcommand args {}

# sdfreadergui::mol_canvas_yscrollcommand --
#
# Callback to handle mol_canvas widget option -yscrollcommand
#
# ARGS:
#    <NONE>
#
proc sdfreadergui::mol_canvas_yscrollcommand args {}

# END CALLBACK CODE

# sdfreadergui::init --
#
#   Call the optional userinit and initialize the dialog.
#   DO NOT EDIT THIS PROCEDURE.
#
# Arguments:
#   root   the root window to load this dialog into
#
# Results:
#   dialog will be created, or a background error will be thrown
#
proc sdfreadergui::init {root args} {
    # Catch this in case the user didn't define it
    catch {sdfreadergui::userinit}
    if {[info exists embed_args]} {
	# we are running in the plugin
	sdfreadergui::ui $root
    } elseif {$::argv0 == [info script]} {
	# we are running in stand-alone mode
	wm title $root sdfreadergui
	if {[catch {
	    # Create the UI
	    sdfreadergui::ui  $root
	} err]} {
	    bgerror $err ; exit 1
	}
    }
    catch {sdfreadergui::run $root}
}
sdfreadergui::init .

