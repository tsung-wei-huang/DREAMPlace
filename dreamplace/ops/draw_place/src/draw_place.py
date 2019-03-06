##
# @file   draw_place.py
# @author Yibo Lin
# @date   Jan 2019
#

import torch 
from torch.autograd import Function

import draw_place_cpp

class DrawPlaceFunction(Function):
    @staticmethod
    def forward(
            pos, 
            node_size_x, node_size_y, 
            pin_offset_x, pin_offset_y, 
            pin2node_map, 
            xl, yl, xh, yh, 
            site_width, row_height, 
            bin_size_x, bin_size_y, 
            num_movable_nodes, num_filler_nodes, 
            filename
            ):
        return draw_place_cpp.forward(
                pos, 
                node_size_x, node_size_y, 
                pin_offset_x, pin_offset_y, 
                pin2node_map, 
                xl, yl, xh, yh, 
                site_width, row_height, 
                bin_size_x, bin_size_y, 
                num_movable_nodes, num_filler_nodes, 
                filename
                )

class DrawPlace(object):
    """ Draw placement
    """
    def __init__(self, placedb):
        self.placedb = placedb 
        self.node_size_x = torch.from_numpy(placedb.node_size_x)
        self.node_size_y = torch.from_numpy(placedb.node_size_y)
        self.pin_offset_x = torch.from_numpy(placedb.pin_offset_x)
        self.pin_offset_y = torch.from_numpy(placedb.pin_offset_y)
        self.pin2node_map = torch.from_numpy(placedb.pin2node_map)
        self.xl = placedb.xl 
        self.yl = placedb.yl 
        self.xh = placedb.xh 
        self.yh = placedb.yh 
        self.site_width = placedb.site_width
        self.row_height = placedb.row_height 
        self.bin_size_x = placedb.bin_size_x 
        self.bin_size_y = placedb.bin_size_y
        self.num_movable_nodes = placedb.num_movable_nodes
        self.num_filler_nodes = placedb.num_filler_nodes

    """ 
    @param filename suffix specifies the format 
    """
    def forward(self, pos, filename): 
        return DrawPlaceFunction.forward(
                pos, 
                self.node_size_x, 
                self.node_size_y, 
                self.pin_offset_x, 
                self.pin_offset_y, 
                self.pin2node_map, 
                self.xl, 
                self.yl, 
                self.xh, 
                self.yh, 
                self.site_width, 
                self.row_height, 
                self.bin_size_x, 
                self.bin_size_y, 
                self.num_movable_nodes, 
                self.num_filler_nodes, 
                filename
                )
    """
    top API 
    """
    def __call__(self, pos, filename):
        return self.forward(pos, filename)