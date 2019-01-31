#!/usr/bin/env fslpython

import argparse

parser = argparse.ArgumentParser('Splits the positive/negative datasets based on the shim group labels')
parser.add_argument('positive_filenames',
                    help='@-seperated list with filenames of the data with positive phase encoding')
parser.add_argument('positive_shim_labels',
                    help='@-seperated list with shim groups for the `positive_filenames`')
parser.add_argument('negative_filenames',
                    help='@-seperated list with filenames of the data with negative phase encoding')
parser.add_argument('negative_shim_labels',
                    help='@-seperated list with shim groups for the `negative_filenames`')
args = parser.parse_args()


pos_filenames = args.positive_filenames.split('@')
pos_labels = args.positive_shim_labels.split('@')
neg_filenames = args.negative_filenames.split('@')
neg_labels = args.negative_shim_labels.split('@')

if len(pos_filenames) != len(pos_labels):
    raise ValueError("Number of filenames with positive phase encoding does not match number of shim groups labels")

if len(neg_filenames) != len(neg_labels):
    raise ValueError("Number of filenames with negative phase encoding does not match number of shim groups labels")

unique_labels = set(pos_labels)

single_labels = unique_labels.symmetric_difference(set(neg_labels))
if len(single_labels) != 0:
    raise ValueError("Shim groups %s can not be processed, because they do not have both positive "
                     "and negative phase encoding data" % ' and '.join(sorted(single_labels)))

for label in sorted(unique_labels):
    print(
            label,
            '@'.join(fn for fn, lab in zip(pos_filenames, pos_labels) if lab == label),
            '@'.join(fn for fn, lab in zip(neg_filenames, neg_labels) if lab == label),
    )

