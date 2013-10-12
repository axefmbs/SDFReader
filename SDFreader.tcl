#!/usr/bin/env wish
package require Tk 8.5

set SCRIPTDIR [file dirname [info script]]

source [file join $SCRIPTDIR sdfparser.tcl ]
source [file join $SCRIPTDIR molparser.tcl ]
source [file join $SCRIPTDIR sdfreadergui.tcl ]

sdfreadergui::init .
sdfreadergui::setup_gui
