/*
 * port.c
 *
 *  Created on: Sep 22, 2019
 *      Author: joelai
 */

#include <moss/moss.h>
#include <cmsis/port.h>

void PORT_setup(MKR4000_PORT_TypeDef *port, char pin, char func, char dir_out) {
	if (func != PORT_func_gpio) {
		port->PMUX[pin / 2] = MOSS_BITWORD(port->PMUX[pin / 2],
				((pin & 1) ? MKR4000_PORT_PMUX_PMUXO_SHIFT : MKR4000_PORT_PMUX_PMUXE_SHIFT),
				MKR4000_PORT_PMUX_PMUX_BITS, func);
		port->PINCFG[pin] |=
				((1 << MKR4000_PORT_PINCFG_PMUXEN_SHIFT) |
				(1 << MKR4000_PORT_PINCFG_INEN_SHIFT));
		return;
	}

	PORT_dir(port, pin, dir_out);
	port->PINCFG[pin] &= ~(1 << MKR4000_PORT_PINCFG_PMUXEN_SHIFT);
	port->PINCFG[pin] |= (1 << MKR4000_PORT_PINCFG_INEN_SHIFT);
}
