/* (Squared) distance between two sets of points. */

/*
 *  Copyright (C) 2020, Ricardo Bruna
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */


#include <string.h>
#include <math.h>
#include "mex.h"
#include "matrix.h"

void mexFunction ( int nlhs, mxArray * plhs [], int nrhs, const mxArray * prhs [] ) {
    double *pos1, *pos2;
    double *dist2;
    double posx, posy, posz;
    double vecx, vecy, vecz;
    
    int siz1, siz2;
    int ind1, ind2, shift;
    
    /* Checks the inputs. */
    if ( nrhs != 2 ) mexErrMsgTxt ( "Invalid number of arguments." );
    if ( !mxIsDouble ( prhs [0] ) | !mxIsDouble ( prhs [1] ) ) mexErrMsgTxt ( "This function requires double data as input." );
    if ( mxGetN ( prhs [0] ) != 3 | mxGetN ( prhs [1] ) != 3 ) mexErrMsgTxt ( "This function requires Nx3 matrices as input." );
    
    /* Gets the input variables */
    pos1 = mxGetData ( prhs [0] );
    pos2 = mxGetData ( prhs [1] );
    siz1 = mxGetM ( prhs [0] );
    siz2 = mxGetM ( prhs [1] );
    
    
    /* Reserves memory for the output array. */
    plhs [0] = mxCreateDoubleMatrix ( siz1, siz2, mxREAL );
    dist2 = mxGetData ( plhs [0] );
    
    /* Goes through the second list of points. */
    for ( ind2 = 0; ind2 < siz2; ind2++ ) {
        
        /* Gets the position of the current point. */
        posx = pos2 [ ind2 ];
        posy = pos2 [ ind2 + siz2 ];
        posz = pos2 [ ind2 + siz2 + siz2 ];
        
        /* Gets the shift to the current column of the distance matrix. */
        shift = ind2 * siz1;
        
        /* Goes through the first list of points. */
        for ( ind1 = 0; ind1 < siz1; ind1++ ) {
            
            /* Gets the vector between both points. */
            vecx = posx - pos1 [ ind1 ];
            vecy = posy - pos1 [ ind1 + siz1 ];
            vecz = posz - pos1 [ ind1 + siz1 + siz1 ];
            
            /* Calculates the distance between both points. */
            dist2 [ shift + ind1 ] = vecx * vecx + vecy * vecy + vecz * vecz;
        }
    }
}
