/*
 * DSPLY.H -- Header for Graph display module
 *
 *  Copyright (C) 1992-1996 by Alef Null. All rights reserved.
 *  Author(s): J Vuori
 *
 *  Modification(s):
 */


int  InitDisplay(int n, char *logo[]);
void PlotStart(double min, double max);
void LabelAxis(int ymax, int ymin, int xmax, int xmin);
void PlotSamples(int n, Bool fComplex, COMPLEX *s);
void ReleaseDisplay(void);
