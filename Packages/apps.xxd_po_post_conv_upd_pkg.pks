--
-- XXD_PO_POST_CONV_UPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_PO_POST_CONV_UPD_PKG
AS
    /*************************************************************************************************/
    /*                                                                                               */
    /* $Header: XXD_PO_POST_CONV_UPD_PKG.pks 1.0 05/05/2014 PwC  $                                   */
    /*                                                                                               */
    /* PACKAGE NAME:  XXD_PO_POST_CONV_UPD_PKG                                                       */
    /*                                                                                               */
    /* PROGRAM NAME:  Deckers Cross Dock PO Update Program                                           */
    /*                                                                                               */
    /* DEPENDENCIES: NA                                                                              */
    /*                                                                                               */
    /* REFERENCED BY: NA                                                                             */
    /*                                                                                               */
    /* DESCRIPTION          : Package Spec for Cross Dock PO Update Program                          */
    /*                                                                                               */
    /* HISTORY:                                                                                      */
    /*-----------------------------------------------------------------------------------------------*/
    /* Verson Num       Developer          Date           Description                                */
    /*                                                                                               */
    /*-----------------------------------------------------------------------------------------------*/
    /* 1.0              PwC                05-May-2015    Initial Version                            */
    /*-----------------------------------------------------------------------------------------------*/
    /*                                                                                               */
    /*************************************************************************************************/
    gc_cross_dock        CONSTANT VARCHAR2 (20) := 'CROSS_DOCK_PO_UPDATE';
    gc_japan_po_update   CONSTANT VARCHAR2 (20) := 'JAPAN_PO_UPDATE';

    PROCEDURE Main (x_retcode OUT NOCOPY NUMBER, x_errbuf OUT NOCOPY VARCHAR2, p_process IN VARCHAR2);
END xxd_po_post_conv_upd_pkg;
/
