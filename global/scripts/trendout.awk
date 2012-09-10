#$Header: /data/petsun4/data1/solaris/csh_scripts/RCS/mtrendout.awk,v 1.3 2012/09/10 06:37:46 avi Exp $
#$Log: mtrendout.awk,v $
# Revision 1.3  2012/09/10  06:37:46  avi
# correct bug in detrending loop
#
# Revision 1.2  2012/09/09  23:10:48  avi
# typo
#
# Revision 1.1  2012/09/09  23:08:56  avi
# Initial revision
#
# Revision 1.2  2009/02/11  22:48:37  avi
# pad output field with space for safety
#
# Revision 1.1  2005/12/02  08:10:05  avi
# Initial revision
#

BEGIN {
	n = 0;
	init = 0;
}

($1 !~/#/) {
	ncol = NF;
	init = 1;
}

(init == 1 && $1 !~/#/) {
	if (NF != ncol) {
		print "format error"
		exit -1;
	}
	for (j = 1; j <= ncol; j++) data[n,j] = $j;
	n++;
}

END {
	for (i = 0; i < n; i++) {
		x[i] = -1. + 2.*i/(n - 1);
	}
	sxx = n*(n+1) / (3.*(n - 1));

	for (j = 1; j <= ncol; j++) {
		sy[j] = 0; sxy[j] = 0;
		for (i = 0; i < n; i++) {
			sy[j]  += data[i,j];
			sxy[j] += data[i,j]*x[i];
		}
		a0[j] = sy[j]/n;
		a1[j] = sxy[j]/sxx;
		for (i = 0; i < n; i++) {
			data[i,j] -= (a0[j] + a1[j]*x[i]);
		}
	}

	for (i = 0; i < n; i++) {
		for (j = 1; j <= ncol; j++) printf ("%10.6f ", data[i,j])
		printf ("\n");
	}
}
