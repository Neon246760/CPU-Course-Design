# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "CLEAR_BYTES_PER_PAGE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CLEAR_PAGES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DELAY_10MS_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DELAY_200MS_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "POWER_WAIT_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "RESET_LOW_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SPI_HALF_PERIOD_CYCLES" -parent ${Page_0}


}

proc update_PARAM_VALUE.CLEAR_BYTES_PER_PAGE { PARAM_VALUE.CLEAR_BYTES_PER_PAGE } {
	# Procedure called to update CLEAR_BYTES_PER_PAGE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CLEAR_BYTES_PER_PAGE { PARAM_VALUE.CLEAR_BYTES_PER_PAGE } {
	# Procedure called to validate CLEAR_BYTES_PER_PAGE
	return true
}

proc update_PARAM_VALUE.CLEAR_PAGES { PARAM_VALUE.CLEAR_PAGES } {
	# Procedure called to update CLEAR_PAGES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CLEAR_PAGES { PARAM_VALUE.CLEAR_PAGES } {
	# Procedure called to validate CLEAR_PAGES
	return true
}

proc update_PARAM_VALUE.DELAY_10MS_CYCLES { PARAM_VALUE.DELAY_10MS_CYCLES } {
	# Procedure called to update DELAY_10MS_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DELAY_10MS_CYCLES { PARAM_VALUE.DELAY_10MS_CYCLES } {
	# Procedure called to validate DELAY_10MS_CYCLES
	return true
}

proc update_PARAM_VALUE.DELAY_200MS_CYCLES { PARAM_VALUE.DELAY_200MS_CYCLES } {
	# Procedure called to update DELAY_200MS_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DELAY_200MS_CYCLES { PARAM_VALUE.DELAY_200MS_CYCLES } {
	# Procedure called to validate DELAY_200MS_CYCLES
	return true
}

proc update_PARAM_VALUE.POWER_WAIT_CYCLES { PARAM_VALUE.POWER_WAIT_CYCLES } {
	# Procedure called to update POWER_WAIT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.POWER_WAIT_CYCLES { PARAM_VALUE.POWER_WAIT_CYCLES } {
	# Procedure called to validate POWER_WAIT_CYCLES
	return true
}

proc update_PARAM_VALUE.RESET_LOW_CYCLES { PARAM_VALUE.RESET_LOW_CYCLES } {
	# Procedure called to update RESET_LOW_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RESET_LOW_CYCLES { PARAM_VALUE.RESET_LOW_CYCLES } {
	# Procedure called to validate RESET_LOW_CYCLES
	return true
}

proc update_PARAM_VALUE.SPI_HALF_PERIOD_CYCLES { PARAM_VALUE.SPI_HALF_PERIOD_CYCLES } {
	# Procedure called to update SPI_HALF_PERIOD_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SPI_HALF_PERIOD_CYCLES { PARAM_VALUE.SPI_HALF_PERIOD_CYCLES } {
	# Procedure called to validate SPI_HALF_PERIOD_CYCLES
	return true
}


proc update_MODELPARAM_VALUE.RESET_LOW_CYCLES { MODELPARAM_VALUE.RESET_LOW_CYCLES PARAM_VALUE.RESET_LOW_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RESET_LOW_CYCLES}] ${MODELPARAM_VALUE.RESET_LOW_CYCLES}
}

proc update_MODELPARAM_VALUE.POWER_WAIT_CYCLES { MODELPARAM_VALUE.POWER_WAIT_CYCLES PARAM_VALUE.POWER_WAIT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.POWER_WAIT_CYCLES}] ${MODELPARAM_VALUE.POWER_WAIT_CYCLES}
}

proc update_MODELPARAM_VALUE.DELAY_200MS_CYCLES { MODELPARAM_VALUE.DELAY_200MS_CYCLES PARAM_VALUE.DELAY_200MS_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DELAY_200MS_CYCLES}] ${MODELPARAM_VALUE.DELAY_200MS_CYCLES}
}

proc update_MODELPARAM_VALUE.DELAY_10MS_CYCLES { MODELPARAM_VALUE.DELAY_10MS_CYCLES PARAM_VALUE.DELAY_10MS_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DELAY_10MS_CYCLES}] ${MODELPARAM_VALUE.DELAY_10MS_CYCLES}
}

proc update_MODELPARAM_VALUE.SPI_HALF_PERIOD_CYCLES { MODELPARAM_VALUE.SPI_HALF_PERIOD_CYCLES PARAM_VALUE.SPI_HALF_PERIOD_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SPI_HALF_PERIOD_CYCLES}] ${MODELPARAM_VALUE.SPI_HALF_PERIOD_CYCLES}
}

proc update_MODELPARAM_VALUE.CLEAR_PAGES { MODELPARAM_VALUE.CLEAR_PAGES PARAM_VALUE.CLEAR_PAGES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CLEAR_PAGES}] ${MODELPARAM_VALUE.CLEAR_PAGES}
}

proc update_MODELPARAM_VALUE.CLEAR_BYTES_PER_PAGE { MODELPARAM_VALUE.CLEAR_BYTES_PER_PAGE PARAM_VALUE.CLEAR_BYTES_PER_PAGE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CLEAR_BYTES_PER_PAGE}] ${MODELPARAM_VALUE.CLEAR_BYTES_PER_PAGE}
}

