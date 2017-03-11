#!/usr/bin/env python3
"""Converts TA assets from SVG to PNG at the size and crop we need.

Requires the following packages:
- imagemagick
- rsvg-convert

To use:
- Put input files (using the same name from the TA site, see `_IN_FILE_RE`)
  in `<working-dir>/in/`.
- Run! Files will output inside `<working-dir>/out/`

"""
from os import listdir, makedirs
from os.path import join
import re
import subprocess

# These values were found through trial and error.
_DESIRED_UNCROPPED_HEIGHT = 29  # First SVG -> PNG size.
_CROPPED_HEIGHT = 25  # Roughly matching Yelp, which is 24.
_CROPPED_WIDTH = 121
_CROP_X_OFFSET = 51
_CROP_Y_OFFSET = 3

_IN_DIR = "in"
_OUT_DIR = "out"

_IN_FILE_RE = re.compile('([0-5]\.[05])-MCID-5.svg$')
_OUT_FILE = "score_ta_{}{}{}.png"

# Must append: height (as str), then input file name.
_RSVG_ARGS = [
        'rsvg-convert',
        '-d', '1200',  # -d & -p seem to not do anything but I'd like them to.
        '-p', '1200',
        '-h',
]


def _convert_svg_to_png(filenames):
    out_files = []
    makedirs(_OUT_DIR, exist_ok=True)
    for filename in filenames:
        score = float(_IN_FILE_RE.search(filename).group(1))

        for scale in range(1, 4):
            args = list(_RSVG_ARGS) + [str(_DESIRED_UNCROPPED_HEIGHT * scale), filename]
            out_file = _get_out_file_name(score, scale)
            out_files.append(out_file)
            with open(out_file, 'x') as f:
                subprocess.call(args, stdout=f)

    return out_files


def _crop_pngs(filenames):
    for filename in filenames:
        tmp = filename.split('@')
        scale = int(tmp[1][0]) if len(tmp) > 1 else 1
        args = _get_crop_args(filename, scale, filename)
        subprocess.call(args)


def _get_in_filenames(in_dir):
    return [join(in_dir, f) for f in listdir(in_dir) if _IN_FILE_RE.search(f)]


def _get_out_file_name(score, scale):
    whole_number = str(score).split('.')[0]
    decimal = "_half" if str(score).split('.')[1] == "5" else ""
    scale_str = "" if scale == 1 else "@{}x".format(scale)
    return join(_OUT_DIR, _OUT_FILE.format(whole_number, decimal, scale_str))


def _get_crop_args(in_file, scale, out_file):
    width = str(_CROPPED_WIDTH * scale)
    height = str(_CROPPED_HEIGHT * scale)
    x_offset = str(_CROP_X_OFFSET * scale)
    y_offset = str(_CROP_Y_OFFSET * scale)
    return [
            'convert',
            in_file,
            '-crop', '{}x{}+{}+{}'.format(width, height, x_offset, y_offset),
            out_file,
    ]


def main():
    in_filenames = _get_in_filenames(_IN_DIR)
    out_files = _convert_svg_to_png(in_filenames)
    _crop_pngs(out_files)
    print('Files saved to \'{}/\''.format(_OUT_DIR))


if __name__ == '__main__':
    main()
