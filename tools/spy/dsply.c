/*
 * DSPLY.C -- Graph display module
 *
 *  Copyright (C) 1992-1996 by Alef Null. All rights reserved.
 *  Author(s): J Vuori
 *
 *  Modification(s):
 *	Feb-1995: multiple line colors
 *	Mar-1996: PlotSample() function added
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <math.h>
#include <graphics.h>
#include "spy.h"
#include "dsply.h"

#define DX 512
#define INT(x)	(int)((x)+.5)

static int GraphDriver, GraphMode;
static struct {
    int    t, b, l, r;
    int    dx, dy;
    double max, scale;
} dimensions;


/* print text to the desired location */
static int cdecl gprintf(int color, int xloc, int yloc, char *fmt, ...) {
    va_list argptr;
    char    str[140];
    int     cnt, oldColor;

    va_start(argptr, fmt);

    cnt = vsprintf(str, fmt, argptr);
    oldColor = getcolor(); setcolor(color);
    outtextxy(xloc, yloc, str);
    setcolor(oldColor);

    va_end(argptr);

    return(cnt);
}


/*
 * Initializes display
 *
 *  n	 is the number of points to be plotted
 *  logo is logo text to be printed on the screen
 *
 *  returns -1 if errors, 0 otherwise
 */
int InitDisplay(int n, char *logo[]) {
    struct viewporttype     vp;
    double		    xyratio, f;
    int 	            ErrorCode,
			    k,
			    xasp, yasp;

    /* first setup driver */
    if(registerbgidriver(EGAVGA_driver) < 0) {
	fprintf(stderr, "Graphics System Error: Can't load internal display driver\n");
	return (-1);
    }
    GraphDriver = DETECT;
    initgraph(&GraphDriver, &GraphMode, "");
    ErrorCode = graphresult();
    if(ErrorCode != grOk) {
	fprintf(stderr, "Graphics System Error: %s\n", grapherrormsg(ErrorCode));
	return (-1);
    }
    restorecrtmode();

    /* then calculate dimensions */
    setgraphmode(GraphMode);
    getviewsettings(&vp); getaspectratio(&xasp, &yasp);
    xyratio	  = (double) (vp.bottom - vp.top) / (double) (vp.right - vp.left) * (double) yasp / (double) xasp;
    dimensions.t  = ((vp.bottom - vp.top) - (int) ((double) n * xyratio * 0.8)) / 2;
    dimensions.b  = dimensions.t + (int) ((double) n * xyratio * 0.8);
    dimensions.l  = ((vp.right - vp.left) - n) / 2;
    dimensions.r  = dimensions.l + n;
    dimensions.dx = dimensions.r - dimensions.l;
    dimensions.dy = dimensions.b - dimensions.t;

    /* put text lines */
    k = 0;
    settextjustify(CENTER_TEXT, TOP_TEXT);
    gprintf(WHITE, dimensions.dx/2+dimensions.l, k += textheight("0"), "%s", *logo++);

    /* put horizontal ticks */
    for (f = dimensions.l; f <= dimensions.r; f += (double)dimensions.dx/8.0) {
	line(INT(f), dimensions.b, INT(f), dimensions.b+dimensions.dy/50);
    }

    /* put vertical ticks */
    settextjustify(RIGHT_TEXT, CENTER_TEXT);
    for (f = dimensions.b; f > dimensions.t; f -= (double)dimensions.dy/5.0)
	line(dimensions.l-dimensions.dx/90, INT(f), dimensions.l, INT(f));
    settextjustify(LEFT_TEXT, CENTER_TEXT);

    settextjustify(CENTER_TEXT, TOP_TEXT);
    while (*logo != NULL)
	gprintf(LIGHTGRAY, dimensions.dx/2+dimensions.l, k += textheight("0"), "%s", *logo++);

    /* put frame */
    rectangle(dimensions.l, dimensions.t, dimensions.r, dimensions.b);

    /* set plotting viewport (and clipping mode) */
    setviewport(dimensions.l+1, dimensions.t+1, dimensions.r-1, dimensions.b-1, 1);

    return (0);
}


/*
 * Start plotting
 */
void PlotStart(double min, double max) {
    struct linesettingstype lineinfo;
    double                  f;
    int 		    oldColor;

    getlinesettings(&lineinfo);
    oldColor = getcolor();

    clearviewport();

    dimensions.max   = max;
    dimensions.scale = (double) dimensions.dy / ((min == max) ? 1.0 : (max - min));

    /* put horizontal ticks */
    setcolor(LIGHTGRAY); setlinestyle(1, lineinfo.upattern, lineinfo.thickness);
    for (f = (double)dimensions.dx/8.0; f < dimensions.dx; f += (double)dimensions.dx/8.0)
	line(INT(f), 0, INT(f), dimensions.dy);

    /* put vertical ticks */
    for (f = dimensions.dy; f > 0; f -= (double)dimensions.dy/5.0) {
	line(0, INT(f), dimensions.dx, INT(f));
    }
    setlinestyle(lineinfo.linestyle, lineinfo.upattern, lineinfo.thickness);

    /* plot zero line if needed */
    setcolor(LIGHTBLUE);
    line(0, INT(dimensions.max * dimensions.scale), dimensions.dx, INT(dimensions.max * dimensions.scale));
    setcolor(oldColor);

}


/*
 * Print Axis Labels
 */
void LabelAxis(int ymax, int ymin, int xmax, int xmin) {
    char       buf[20] ;
    const char blank[] = {"лллллл"};
    int        xpos, ypos;

    /* reset viewport */
    setviewport(0, 0, getmaxx(), getmaxy(), 0);

    settextjustify(LEFT_TEXT, CENTER_TEXT);

    /* blank old labels */
    setcolor(BLACK);
    outtextxy(0, dimensions.t, (char*)&blank[0]);
    outtextxy(0, dimensions.b, (char*)&blank[0]);

    /* print y-max label */
    sprintf(&buf[0], "%+6d", ymax);
    setcolor(LIGHTGRAY);
    outtextxy(0, dimensions.t, &buf[0]);

    /* print y-min label */
    sprintf(&buf[0], "%+6d", ymin);
    outtextxy(0, dimensions.b, &buf[0]);


    settextjustify(CENTER_TEXT, TOP_TEXT);
    setcolor(LIGHTGRAY);
    ypos = dimensions.b+dimensions.dy/50+textheight("0") ;

    /* erase old labels */
    setfillstyle(SOLID_FILL,BLACK);
    bar(dimensions.l-20,ypos-1,dimensions.r+20,ypos+textheight("0")+1);

    /* print x-min label */
    //gprintf(LIGHTGRAY, INT(f), dimensions.b+dimensions.dy/50+textheight("0"), "%d", INT(((double)f - (double)dimensions.l) / (double)dimensions.dx * n));
    sprintf(&buf[0], "%d", xmin);
    outtextxy(dimensions.l, ypos, &buf[0]);

    /* print middle x label */
    sprintf(&buf[0], "%d", xmin+(xmax-xmin)/2);
    xpos = dimensions.l+dimensions.dx/2;
    outtextxy(xpos, ypos, &buf[0]);

    /* print x-max label */
    sprintf(&buf[0], "%d", xmax);
    outtextxy(dimensions.r, ypos, &buf[0]);

    /* plot inside axis only */
    setviewport(dimensions.l+1, dimensions.t+1, dimensions.r-1, dimensions.b-1, 1);
}


/*
 * Plot given data series
 */
void PlotSamples(int n, Bool fComplex, COMPLEX *s) {
    int      step = DX/n, x;
    int      oldColor = getcolor();
    COMPLEX *p;

    /* first real part */
    setcolor(YELLOW);
    moveto(0, INT((dimensions.max - s->x) * dimensions.scale)); x = 0;
    for (p = s; p < &s[n]; p++) {
	int y = INT((dimensions.max - p->x) * dimensions.scale);

	lineto(x, y);
	if (step > 3)
	    circle(x, y, 3);

	x += step;
    }

    /* then complex part */
    if (fComplex) {
	setcolor(MAGENTA);
	moveto(0, INT((dimensions.max - s->y) * dimensions.scale)); x = 0;
	for (p = s; p < &s[n]; p++) {
	    int y = INT((dimensions.max - p->y) * dimensions.scale);

	    lineto(x, y);
	    if (step > 3)
		circle(x, y, 3);

	    x += step;
	}
    }

    setcolor(oldColor);
}



/*
 * releases display
 */
void ReleaseDisplay(void) {
    closegraph();
}
