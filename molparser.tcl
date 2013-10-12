namespace eval MOL {

	variable version " 2009.1"
	variable mol_lines {}
	variable mol_name ""
	variable mol_comment ""
	variable mol_app  ""
	variable mol_date ""
	variable atoms_no 0
	variable bonds_no 0
	variable atoms
	variable bonds
	array set atoms {}
	array set bonds {}
	#lists for sorting coordinates
	variable x_coord {}
	variable y_coord {}
	# range of coordinates
	variable x_range 0
	variable y_range 0
	variable scale_factor 1
	variable atom_color
	array set atom_color {
		N	blue
		O	red
		S	yellow4
		F	cyan3
		Cl	green3
		Br	brown
		I	VioletRed
		P	VioletRed4
		Si	salmon3
		B	DarkCyan
	}

	variable bond_color "#444444"
	variable bond_width  2
	variable font_size 10
	variable font_face "Times"
	variable clean_radius 12
	variable structure_canvas ""
	variable canvas_bg "white"
	variable canvas_w
	variable canvas_h
	# mouse event coordinates
	variable xc 0
	variable yc 0
	# calculated center point of canvas
	variable dx 0
	variable dy 0

	variable nearest ""

}

proc MOL::assign_canvas { canvas } \
{
	set MOL::structure_canvas $canvas
} ; # end proc

proc MOL::clear_canvas {  } \
{
	$MOL::structure_canvas delete "all"
} ; # end proc

proc MOL::create_postscript {} {
	#$MOL::structure_canvas postscript -file "/tmp/test.eps"
}

proc MOL::error_message { err_code } {
	set text ""
	switch $err_code {
		1	{set text "NO MOL DATA"}
		2	{set text "NOT MOL DATA"}
		3	{set text "BAD ATOMS NUMBER IN MOL DATA"}
		4	{set text "BAD BONDS NUMBER IN MOLDATA"}
		5   {set text "BAD COORDINATES NUMBER IN MOLDATA"}
		default {set text "ERROR ANALYZING MOLDATA"}
	}

	# tk_messageBox -icon error -type ok\
	# -message "$text"
	 puts stderr "$text"
	 set SDF::status2 "$text"
	 #exit 0
}



proc MOL::rescale { w h } {

	# handler for rescaling window

 	set MOL::canvas_w $w
	set MOL::canvas_h $h
 	#$MOL::structure_canvas configure -width $w -height $h
 	DEBUG::put 8 "w: $w h: $h"
 	#DEBUG::put 7 "x_rangEe $MOL::x_range"
 	#DEBUG::put 7 [llength $MOL::x_coord]


 	if { [llength $MOL::x_coord] > 0 }  MOL::draw_molecule

}

proc MOL::find_nearest { x y } \
{
	set MOL::xc $x; set MOL::yc $y; \
	set MOL::nearest [$MOL::structure_canvas find closest $MOL::xc $MOL::yc]; \
	DEBUG::put 8 "$MOL::nearest @ $MOL::xc $MOL::yc"
} ; # end proc

proc MOL::move { x y } {

	#handler for moving molecule

   $MOL::structure_canvas move all [expr {$x-$MOL::xc}] [expr {$y-$MOL::yc}]

   set MOL::xc $x
   set MOL::yc $y

 }

proc MOL::parse_header { } {

#The Header Block
#Line 1:    Molecule name. This line is unformatted, but like all other lines in a molfile may not extend beyond
		 #column 80. If no name is available, a blank line must be present.
		 #Caution: This line must not contain any of the reserved tags that identify any of the other CTAB file
		 #types such as $MDL (RGfile), $$$$ (SDfile record separator), $RXN (rxnfile), or $RDFILE (RDfile
		 #headers).
#Line 2:    This line has the format:
							#IIPPPPPPPPMMDDYYHHmmddSSssssssssssEEEEEEEEEEEERRRRRR
		 #(FORTRAN:          A2<--A8--><---A10-->A2I2<--F10.5-><---F12.5--><-I6-> )
		 #User's first and last initials (l), program name (P), date/time (M/D/Y,H:m), dimensional codes (d),
		 #scaling factors (S, s), energy (E) if modeling program input, internal registry number (R) if input
		 #through MDL form.
		 #A blank line can be substituted for line 2.
		 #If the internal registry number is more than 6 digits long, it is stored in an M  REG line (described in
		 #Chapter 3).
#Line 3:    A line for comments. If no comment is entered, a blank line must be present.


		variable mol_lines
		#first line
		if {[MOL::next_line MOL::mol_name]} {
			DEBUG::put 8 "molname: $MOL::mol_name"
		} else {
			DEBUG::put 8 "error 1 inside parse header"
			error_message  1
			return error
		}

		#second line
		if {[MOL::next_line line]} {
			DEBUG::put 8 "second line: $line"
			set MOL::mol_app [string range $line 0 9]
			DEBUG::put 8 "application: $MOL::mol_app"
			set MOL::mol_date [string range $line 10 19]
			DEBUG::put 8 "date: $MOL::mol_date"
		} else {
			DEBUG::put 8 "error 2 inside parse header second line"
			error_message  2
			return error
		}


		#3rd line
		if {[MOL::next_line MOL::mol_comment]} {
			DEBUG::put 8 "MOL::mol_comment: $MOL::mol_comment"
		} else {
			DEBUG::put 8 "error 2 inside parse header, third line"
			error_message  1
			return error
		}

}

proc MOL::parse_table {} {

		#The Counts Line
                #aaabbblllfffcccsssxxxrrrpppiiimmmvvvvvv
                #WhereMOL::
                #aaa       = number of atoms (current max 255)*        [Generic]
                #bbb       = number of bonds (current max 255)*        [Generic]
                #lll       = number of atom lists (max 30)*            [Query]
                #fff       = (obsolete)
                #ccc       = chiral flag: 0=not chiral, 1=chiral       [Generic]
                #sss       = number of stext entries                   [ISIS/Desktop]
                #xxx       = (obsolete)
                #rrr       = (obsolete)
                #ppp       = (obsolete)
                #iii       = (obsolete)
                #mmm       = number of lines of additional properties, [Generic]
                          #including the M END line. No longer
                          #supported, the default is set to 999.


		MOL::next_line line

		if { [string length $line] >= 6} {
        	DEBUG::put 8 "count line as string:$line"
        	set MOL::atoms_no [string range $line 0 2]
        	set MOL::bonds_no [string range $line 3 5]
        	DEBUG::put 8 "atoms count: $MOL::atoms_no"
        	DEBUG::put 8 "bonds count: $MOL::bonds_no"
        	if {$MOL::atoms_no <= 0} {
        		DEBUG::put 2 "error 3 inside parse table"
        		error_message 3
        		return error
		}; #end internal if

			if {[parse_atoms ] == "error"} {
				return error
			}

			if {[parse_bonds ] == "error"} {
				return error
			}

			sort_coordinates
			normalize_position

		} else {
			DEBUG::put 2 "error 2 inside parse table"
			error_message  2
			return error
		}; #endif

}; #endproc

proc MOL::parse_bonds { } {

#The Bond Block is made up of bond lines, one line per bond, with the following format:
#111222tttsssxxxrrrccc
#where the values are described in the following table:
#Field Meaning                 Values                                            Notes
#111   first atom number       1 - number of atoms                               [Generic]
#222   second atom number      1 - number of atoms                               [Generic]
#ttt   bond type               1 = Single, 2 = Double,                           [Query] Values 4 through 8
							  #3 = Triple, 4 = Aromatic,                         are for SSS queries only.
							  #5 = Single or Double,
							  #6 = Single or Aromatic,
							  #7 = Double or Aromatic, 8 = Any
#sss   bond stereo             Single bonds: 0 = not stereo,                     [Generic] The wedge
							  #1 = Up, 4 = Either,                               (pointed) end of the stereo
							  #6 = Down, Double bonds: 0 = Use x-, y-, z-coords  bond is at the first atom
							  #from atom block to determine cis or trans,        (Field 111 above)
							  #3 = Cis or trans (either) double bond
#xxx   not used
#rrr   bond topology           0 = Either, 1 = Ring, 2 = Chain                   [Query] SSS queries only.
#ccc   reacting center status  0 = unmarked, 1 = a center, -1 = not a center,    [Reaction, Query]
							  #Additional: 2 = no change,
							  #4 = bond made/broken,
							  #8 = bond order changes
							  #12 = 4+8 (both made/broken and changes);
							  #5 = (4 + 1), 9 = (8 + 1), and 13 = (12 + 1)
							  #are also possible

	for {set x 0} {$x<$MOL::bonds_no} {incr x} {
		if {[next_line line]  && [string length $line] >= 9 } {
			DEBUG::put 7 "bonds line:$line length: [string length $line]"
			set MOL::bonds($x,from) [string trim [string range $line 0 2]]
			set MOL::bonds($x,to) [string trim [string range $line 3 5]]
			set MOL::bonds($x,type) [string trim [string range $line 6 8]]
			#set MOL::bonds($x,stereo) [string trim [string range $line 9 11]]
			DEBUG::put 7 "MOL::bonds($x,from) $MOL::bonds($x,from)"
			DEBUG::put 7 "MOL::bonds($x,to) $MOL::bonds($x,to)"
			DEBUG::put 7 "MOL::bonds($x,type) $MOL::bonds($x,type)"
			#DEBUG::put 7 "MOL::bonds($x,stereo) $MOL::bonds($x,stereo)"
		} else {
			DEBUG::put 2 "error 4 inside parse bonds"
			error_message 4
			return error
		} ; # endif
	};#end for
}; #end parse_bonds

proc MOL::draw_carbon_atoms { } {

	# empty area for carbon atoms should be drawn before the bonds
	# empty area is drawn to make sure we can select it later

	for {set a 1} {$a<=$MOL::atoms_no} {incr a} {

		set symbol $MOL::atoms($a,symbol)
		#DEBUG::put 7 $symbol

		if { $symbol == "C" } {

			set x [expr {$MOL::dx + $MOL::atoms($a,x) * $MOL::scale_factor} ]
			set y [expr {$MOL::dy + $MOL::atoms($a,y) * $MOL::scale_factor} ]

			set x1 [expr { $x-$MOL::clean_radius } ]
			set x2 [expr { $x+$MOL::clean_radius } ]
			set y1 [expr { $y-$MOL::clean_radius } ]
			set y2 [expr { $y+$MOL::clean_radius } ]

			$MOL::structure_canvas create oval $x1 $y1 $x2 $y2 -fill $MOL::canvas_bg\
			 -outline $MOL::canvas_bg -activeoutline  orange -tag carbon_atom
			#$MOL::structure_canvas create text $x $y -text $symbol -font "Times $MOL::font_size bold" -activefill red
		} else {
			# no carbon - skip
		}
	};#end for
}

proc MOL::draw_other_atoms { } {

	# these non carbon atoms should be drawn after the bonds

	for {set a 1} {$a<=$MOL::atoms_no} {incr a} {

		set symbol $MOL::atoms($a,symbol)
		#DEBUG::put 7 $symbol

		if { $symbol != "C" } {

			set x [expr {$MOL::dx + $MOL::atoms($a,x) * $MOL::scale_factor} ]
			set y [expr {$MOL::dy + $MOL::atoms($a,y) * $MOL::scale_factor} ]

			set x1 [expr { $x-$MOL::clean_radius } ]
			set x2 [expr { $x+$MOL::clean_radius } ]
			set y1 [expr { $y-$MOL::clean_radius } ]
			set y2 [expr { $y+$MOL::clean_radius } ]

			set color "#777777"
			catch {
				set color $MOL::atom_color($symbol)
			}

			$MOL::structure_canvas create oval $x1 $y1 $x2 $y2 -fill $MOL::canvas_bg -outline $MOL::canvas_bg;# -activeoutline red
			$MOL::structure_canvas create text $x $y -text $symbol \
			-font "$MOL::font_face $MOL::font_size bold" \
			-fill $color -activefill orange -tag atom_symbol
		} else {
			# we have carbon - skip
		}
	};#end for
}

proc MOL::calculate_canvas_center {} {

	# calculate sizes of the canvas
	#set hx [$MOL::structure_canvas cget -width]
	#set hy [$MOL::structure_canvas cget -height]
	set hx $MOL::canvas_w
	set hy $MOL::canvas_h
 	#DEBUG::put 7 "hx: $hx"
 	#DEBUG::put 7 "hy: $hy"

	#calculate half sizes of the molecule after scaling
	set mx [expr {$MOL::scale_factor * $MOL::x_range}]
	set my [expr {$MOL::scale_factor * $MOL::y_range}]
	#set mx [expr {$mx/2}]
	#set my [expr {$my/2}]

	set MOL::dx [expr {($hx - $mx)/2}]
	set MOL::dy [expr {($hy - $my)/2}]

}

proc MOL::draw_bonds {} {

	if { $MOL::canvas_h < 180 || $MOL::canvas_w < 180 } {
 		set MOL::font_size 7
 		set MOL::clean_radius 6
 		#set MOL::bond_width 1
	} elseif { $MOL::canvas_h > 350 && $MOL::canvas_w > 350 }  {
		set MOL::font_size 12
		set MOL::clean_radius 10
		#set MOL::bond_width 2
	} else {
		set MOL::font_size 10
		set MOL::clean_radius 8
		#set MOL::bond_width 2
	}

	for {set i 0} {$i<$MOL::bonds_no} {incr i} {

		set from $MOL::bonds($i,from)
	    set to   $MOL::bonds($i,to)
	    set type $MOL::bonds($i,type)

		set x1 [expr {$MOL::dx + $MOL::atoms($from,x) * $MOL::scale_factor} ]
		set y1 [expr {$MOL::dy + $MOL::atoms($from,y) * $MOL::scale_factor} ]
		set x2 [expr {$MOL::dx + $MOL::atoms($to,x) * $MOL::scale_factor} ]
		set y2 [expr {$MOL::dy + $MOL::atoms($to,y) * $MOL::scale_factor} ]

		if { $type == 1 || $type > 2} {
			# single bond when single and when other than 2 or 3
			$MOL::structure_canvas create line $x1 $y1 $x2 $y2 -width $MOL::bond_width \
			-fill $MOL::bond_color -activefill orange -activewidth 4 -tag bond
		}

		if { $type == 2 || $type == 3} {
			# double bond when 2 or 3
			# calculate orthogonal vector
			set dx [expr { $x2 - $x1}]
			set dy [expr { $y2 - $y1}]

			set ort_x [expr { - $dy }]
			set ort_y $dx

			#normalize to largest absolute value

			set abs_x [expr { abs($ort_x) }]
			set abs_y [expr { abs($ort_y) }]

			set max [expr {$abs_x > $abs_y ? $abs_x : $abs_y}]

			set ort_x [expr {$ort_x / $max }]
			set ort_y [expr {$ort_y / $max }]

			# DEBUG::put 7 "bond vector: $dx 	$dy"
			# DEBUG::put 7 "ortogonal  : $ort_x	$ort_y"

			# calculate translated coordinates

			set distance [expr {$type == 2 ? 2 : 4}]

			set x1t1 [expr { $x1 + $distance * $ort_x }]
			set x1t2 [expr { $x1 - $distance * $ort_x }]
			set y1t1 [expr { $y1 + $distance * $ort_y }]
			set y1t2 [expr { $y1 - $distance * $ort_y }]

			set x2t1 [expr { $x2 + $distance * $ort_x }]
			set x2t2 [expr { $x2 - $distance * $ort_x }]
			set y2t1 [expr { $y2 + $distance * $ort_y }]
			set y2t2 [expr { $y2 - $distance * $ort_y }]

			$MOL::structure_canvas create line $x1t1 $y1t1 $x2t1 $y2t1 -width $MOL::bond_width \
			-fill $MOL::bond_color -activefill orange -activewidth 4 -tag bond
			$MOL::structure_canvas create line $x1t2 $y1t2 $x2t2 $y2t2 -width $MOL::bond_width \
			-fill $MOL::bond_color -activefill orange -activewidth 4 -tag bond
		}; #endif
	}; #end for

}; #end proc

proc MOL::parse_atoms { } {

#The Atom Block
#is made up of atom lines, one line per atom with the following format:
#xxxxx.xxxxyyyyy.yyyyzzzzz.zzzz aaaddcccssshhhbbbvvvHHHrrriiimmmnnneee
#where the values are described in the following table:
#Field Meaning                  Values                                      Notes
#xyz   atom coordinates                                                     [Generic]
#aaa   atom symbol              entry in periodic table or L for atom list, [Generic, Query, 3D, Rgroup]
                               #A, Q, * for unspecified atom, and LP for
                               #lone pair, or R# for Rgroup label
#dd    mass difference          -3, -2, -1, 0, 1, 2, 3, 4                   [Generic] Difference from
                               #(0 if value beyond these limits)            mass in periodic table. Wider
                                                                           #range of values allowed by
                                                                           #M ISO line, below. Retained
                                                                           #for compatibility with older
                                                                           #Ctabs, M ISO takes
                                                                           #precedence.
#ccc   charge                   0 = uncharged or value other than           [Generic] Wider range of
                               #these, 1 = +3, 2 = +2, 3 = +1,              values in M CHG and M RAD
                               #4 = doublet radical, 5 = -1, 6 = -2, 7 = -3 lines below. Retained for
                                                                           #compatibility with older Ctabs,
                                                                           #M CHG and M RAD lines
                                                                           #take precedence.
#sss   atom stereo parity       0 = not stereo, 1 = odd, 2 = even,          [Generic] Ignored when read.
                               #3 = either or unmarked stereo center
#hhh   hydrogen count + 1       1 = H0, 2 = H1, 3 = H2, 4 = H3,             [Query] H0 means no H atoms
                               #5 = H4                                      allowed unless explicitly drawn.
                                                                           #Hn means atom must have n or
                                                                           #more Hs in excess of explicit
                                                                           #Hs.
#bbb   stereo care box          0 = ignore stereo configuration of this     [Query] Double bond
                               #double bond atom, 1 = stereo                stereochemistry is considered
                               #configuration of double bond atom           during SSS only if both ends of
                               #must match                                  the bond are marked with
                                                                           #stereo care boxes.
#vvv   valence                  0 = no marking (default)                    [Generic] Shows number of
                               #(1 to 14) = (1 to 14) 15 = zero valence     bonds to this atom, including
                                                                           #bonds to implied H's.
#HHH   H0 designator            0 = not specified, 1 = no H atoms           [ISIS/Desktop] Redundant with
                               #allowed                                     hydrogen count information.
                                                                           #May be unsupported in future
                                                                           #releases of Symyx software.
#rrr   Not used
#iii   Not used
#mmm   atom-atom mapping        1 - number of atoms                         [Reaction]
      #number
#nnn   inversion/retention flag 0 = property not applied                    [Reaction]
                               #1 = configuration is inverted,
                               #2 = configuration is retained,
#eee   exact change flag        0 = property not applied,                   [Reaction, Query]
                               #1 = change on atom must be exactly as
                               #shown
	variable mol_lines
	set MOL::x_coord {}
	set MOL::y_coord {}
	for {set a 1} {$a<=$MOL::atoms_no} {incr a} {
		if {[next_line line] && [string length $line] >= 34 } {
			DEBUG::put 8 "atoms line:$line"
			set MOL::atoms($a,x) [string range $line 0 9]
			set MOL::atoms($a,y) [string range $line 10 19]
			# here populate lists for sorting to normalize size
			lappend MOL::x_coord $MOL::atoms($a,x)
			lappend MOL::y_coord $MOL::atoms($a,y)
			set MOL::atoms($a,z) [string range $line 20 29]
			set MOL::atoms($a,symbol) [string trim [string range $line 31 33]]
			#DEBUG::put 7 "MOL::atoms($a,x) $MOL::atoms($a,x)"
			#DEBUG::put 7 "MOL::atoms($a,y) $MOL::atoms($a,y)"
			#DEBUG::put 7 "MOL::atoms($a,z) $MOL::atoms($a,z)"
			#DEBUG::put 7 "MOL::atoms($a,symbol) $MOL::atoms($a,symbol)"
		} else {
			DEBUG::put 8 "error 3 inside parse atoms"
			error_message 3
			return error
		} ; # endif
	};#end for

}; #end parse_atoms


proc MOL::next_line { v } \
{	variable mol_lines
	upvar $v local
	set problem [catch \
	{
		set local [lindex $mol_lines 0]
		set mol_lines [lrange $mol_lines 1 end]
	} zonk ]
	if { $problem } \
	{
		DEBUG::put 8 "problem in [info level 0]: $zonk"
		return 0
	} else {
		return 1
	}
} ; # end proc


proc MOL::calculate_range {} {
	# range of coordinates
	set x_beg [lindex $MOL::x_coord 0]
	set x_end [lindex $MOL::x_coord end]
	set y_beg [lindex $MOL::y_coord 0]
	set y_end [lindex $MOL::y_coord end]
	set MOL::x_range [expr { $x_end - $x_beg }]
	set MOL::y_range [expr { $y_end - $y_beg }]
	DEBUG::put 7 "x_beg: $x_beg"
	DEBUG::put 7 "x_end: $x_end"
	DEBUG::put 7 "x_range: $MOL::x_range"
	DEBUG::put 7 "y_range: $MOL::y_range"

}

proc MOL::calculate_scale_factor {} {

	# in fact this calculate scaling factor only
	# values in array are not modified

	calculate_range

	if {$MOL::x_range == 0 || $MOL::y_range == 0} {
		DEBUG::put 2 "error 5 inside calculating scale"
		error_message 5
        return error
	}

	#set canvas_w [$MOL::structure_canvas cget -width]
	#set canvas_h [$MOL::structure_canvas cget -height]
	set x_factor [expr { 0.7 * $MOL::canvas_w / $MOL::x_range} ]
	set y_factor [expr { 0.7 * $MOL::canvas_h / $MOL::y_range} ]
	DEBUG::put 7 "x-factor: $x_factor"
	DEBUG::put 7 "y-factor: $y_factor"
	set MOL::scale_factor  [expr { ($x_factor < $y_factor) ? $x_factor : $y_factor}]
	DEBUG::put 7 "global scale factor: $MOL::scale_factor"
}

proc MOL::normalize_position {} {

	# substract smallest coordinates in order to avoid negative or very big values

	set x_beg [lindex $MOL::x_coord 0]
	set y_beg [lindex $MOL::y_coord 0]

	for {set a 1} {$a<=$MOL::atoms_no} {incr a} {
			set MOL::atoms($a,x) [expr {$MOL::atoms($a,x) - $x_beg} ]
			set MOL::atoms($a,y) [expr {$MOL::atoms($a,y) - $y_beg} ]
	};#end for

	#parray MOL::atoms
}

proc MOL::sort_coordinates {} {

	#make sure the lists contains sorted coordinates

	#DEBUG::put 7 "lista x: $MOL::x_coord"
	#DEBUG::put 7 "lista y: $MOL::y_coord"
	#DEBUG::put 7 "sorting"
	set MOL::x_coord [lsort -real $MOL::x_coord]
	set MOL::y_coord [lsort -real $MOL::y_coord]
	DEBUG::put 7 "lista x: $MOL::x_coord"
	DEBUG::put 7 "lista y: $MOL::y_coord"
}

proc MOL::draw_molecule {} {

	MOL::clear_canvas
	if { [calculate_scale_factor] == "error" } {
		return error
	}
	calculate_canvas_center
	draw_carbon_atoms
	draw_bonds
	draw_other_atoms
}

proc MOL::create_structure {moldata} \
{
	variable mol_lines
	set mol_lines [split $moldata "\n"]

	DEBUG::put 8 "moldata: $moldata"
	DEBUG::put 8 "mol_lines: $mol_lines"

	if { [MOL::parse_header ] == "error" } return
	if { [MOL::parse_table ] == "error" } return

	if { [MOL::draw_molecule] == "error" } return

}


# set_global_vars
# main
