### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##
#
#   See COPYING file distributed along with the gradunwarp package for the
#   copyright and license terms.
#
### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##
from collections import namedtuple
import numpy as np
import logging
import re
import globals
from globals import siemens_cas, ge_cas


log = logging.getLogger('gradunwarp')


Coeffs = namedtuple('Coeffs', 'alpha_x, alpha_y, alpha_z, \
                        beta_x, beta_y, beta_z, R0_m')


def get_coefficients(vendor, cfile):
    ''' depending on the vendor and the coefficient file,
    return the spherical harmonics coefficients as a named tuple.
    '''
    log.info('Parsing ' + cfile + ' for harmonics coeffs')
    if vendor == 'siemens' and cfile.endswith('.coef'):
        return get_siemens_coef(cfile)
    if vendor == 'siemens' and cfile.endswith('.grad'):
        return get_siemens_grad(cfile)


def coef_file_parse(cfile, txt_var_map):
    ''' a separate function because GE and Siemens .coef files
    have similar structure

    modifies txt_var_map in place
    '''
    # parse .coef file. Strip unneeded characters. a valid line in that file is
    # broken into validline_list
    coef_re = re.compile('^[^\#]')  # regex for first character not a '#'
    coef_file = open(cfile, 'r')
    for line in coef_file.readlines():
        if coef_re.match(line):
            validline_list = line.lstrip(' \t').rstrip(';\n').split()
            if validline_list:
                log.info('Parsed : %s' % validline_list)
                l = validline_list
                x = int(l[1])
                y = int(l[2])
                txt_var_map[l[0]][x, y] = float(l[3])


def get_siemens_coef(cfile):
    ''' Parse the Siemens .coef file.
    Note that R0_m is not explicitly contained in the file
    '''
    R0m_map = {'sonata': 0.25,
               'avanto': 0.25,
               'quantum': 0.25,
               'allegra': 0.14,
               'as39s': 0.25,
               'as39st': 0.25,
               'as39t': 0.25}
    for rad in R0m_map.keys():
        if cfile.startswith(rad):
            R0_m = R0m_map[rad]

    coef_array_sz = siemens_cas
    # allegra is slightly different
    if cfile.startswith('allegra'):
        coef_array_sz = 15
    ax = np.zeros((coef_array_sz, coef_array_sz))
    ay = np.zeros((coef_array_sz, coef_array_sz))
    az = np.zeros((coef_array_sz, coef_array_sz))
    bx = np.zeros((coef_array_sz, coef_array_sz))
    by = np.zeros((coef_array_sz, coef_array_sz))
    bz = np.zeros((coef_array_sz, coef_array_sz))
    txt_var_map = {'Alpha_x': ax,
                   'Alpha_y': ay,
                   'Alpha_z': az,
                   'Beta_x': bx,
                   'Beta_y': by,
                   'Beta_z': bz}

    coef_file_parse(cfile, txt_var_map)

    return Coeffs(ax, ay, az, bx, by, bz, R0_m)


def get_ge_coef(cfile):
    ''' Parse the GE .coef file.
    '''
    ax = np.zeros((ge_cas, ge_cas))
    ay = np.zeros((ge_cas, ge_cas))
    az = np.zeros((ge_cas, ge_cas))
    bx = np.zeros((ge_cas, ge_cas))
    by = np.zeros((ge_cas, ge_cas))
    bz = np.zeros((ge_cas, ge_cas))
    txt_var_map = {'Alpha_x': ax,
                   'Alpha_y': ay,
                   'Alpha_z': az,
                   'Beta_x': bx,
                   'Beta_y': by,
                   'Beta_z': bz}

    coef_file_parse(cfile, txt_var_map)

    return Coeffs(ax, ay, az, bx, by, bz, R0_m)

def grad_file_parse(gfile, txt_var_map):
    ''' a separate function because GE and Siemens .coef files
    have similar structure

    modifies txt_var_map in place
    '''
    gf = open(gfile, 'r')
    line = gf.next()
    # skip the comments
    while not line.startswith('#*] END:'):
        line = gf.next()

    # get R0
    line = gf.next()
    line = gf.next()
    line = gf.next()
    R0_m = float(line.strip().split()[0])

    # go to the data
    line = gf.next()
    line = gf.next()
    line = gf.next()
    line = gf.next()
    line = gf.next()
    line = gf.next()
    line = gf.next()

    xmax = 0
    ymax = 0

    while 1:
        lindex =  line.find('(')
        rindex =  line.find(')')
        if lindex == -1 and rindex == -1:
            break
        arrindex = line[lindex+1:rindex]
        xs, ys = arrindex.split(',')
        x = int(xs) 
        y = int(ys)
        if x > xmax:
            xmax = x
        if y > ymax:
            ymax = y
        if line.find('A') != -1 and line.find('x') != -1:
            txt_var_map['Alpha_x'][x,y] = float(line.split()[-2])
        if line.find('A') != -1 and line.find('y') != -1:
            txt_var_map['Alpha_y'][x,y] = float(line.split()[-2])
        if line.find('A') != -1 and line.find('z') != -1:
            txt_var_map['Alpha_z'][x,y] = float(line.split()[-2])
        if line.find('B') != -1 and line.find('x') != -1:
            txt_var_map['Beta_x'][x,y] = float(line.split()[-2])
        if line.find('B') != -1 and line.find('y') != -1:
            txt_var_map['Beta_y'][x,y] = float(line.split()[-2])
        if line.find('B') != -1 and line.find('z') != -1:
            txt_var_map['Beta_z'][x,y] = float(line.split()[-2])
        try:
            line = gf.next()
        except StopIteration:
            break

    # just return R0_m but also txt_var_map is returned
    return R0_m, (xmax, ymax)

def get_siemens_grad(gfile):
    ''' Parse the siemens .grad file
    '''
    coef_array_sz = siemens_cas
    # allegra is slightly different
    if gfile.startswith('coef_AC44'):
        coef_array_sz = 15
    ax = np.zeros((coef_array_sz, coef_array_sz))
    ay = np.zeros((coef_array_sz, coef_array_sz))
    az = np.zeros((coef_array_sz, coef_array_sz))
    bx = np.zeros((coef_array_sz, coef_array_sz))
    by = np.zeros((coef_array_sz, coef_array_sz))
    bz = np.zeros((coef_array_sz, coef_array_sz))
    txt_var_map = {'Alpha_x': ax,
                   'Alpha_y': ay,
                   'Alpha_z': az,
                   'Beta_x': bx,
                   'Beta_y': by,
                   'Beta_z': bz}

    R0_m, max_ind = grad_file_parse(gfile, txt_var_map)
    ind = max(max_ind)

    # pruned alphas and betas
    ax = ax[:ind+1, :ind+1]
    ay = ay[:ind+1, :ind+1]
    az = az[:ind+1, :ind+1]
    bx = bx[:ind+1, :ind+1]
    by = by[:ind+1, :ind+1]
    bz = bz[:ind+1, :ind+1]

    return Coeffs(ax, ay, az, bx, by, bz, R0_m)

