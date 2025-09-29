/*  SERIAL.H -- Header for IBM Serial Port handler (with interrupts)
 *
 *  Copyright (C) by Alef Null 1989,1990,1991
 *  Author(s): J Vuori, E Torsti
 *  Modification(s):
 *	1989-Sep: COM1, COM2 and baud rate selection with
 *		  OpenSerial(int port, int baud)
 *	1991-Apr: DTR line control and baud rate setting functions added
 */

int  OpenSerial(int port, int baud);
void CloseSerial(void);
int  ReadSerial(void);
int  WriteSerial(int c);
void SetBaudRate(int baud);
void SetDTR(int state);
