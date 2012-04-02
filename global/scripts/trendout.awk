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

	for (j = 0; j < ncol; j++) {
		sy[j] = 0; sxy[j] = 0;
		for (i = 0; i < n; i++) {
			sy[j]  += data[i,j];
			sxy[j] += data[i,j]*x[i];
		}
		a0[j] = sy[j]/n;
		a1[j] = sxy[j]/sxx;
		for (i = 0; i < n; i++) {
			data[i,j] -= a1[j]*x[i];
		}
	}

	for (i = 0; i < n; i++) {
		for (j = 1; j <= ncol; j++) printf ("%10.6f", data[i,j])
		printf ("\n");
	}
}
