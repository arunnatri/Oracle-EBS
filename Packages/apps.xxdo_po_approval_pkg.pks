--
-- XXDO_PO_APPROVAL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdo_po_approval_pkg
IS
    /**********************************************************************************************************
     File Name    : xxdo_po_approval_pkg
     Created On   : 27-March-2012
     Created By   : Sivakumar Boothathan
     Purpose      : This Package is to take a PO as an input and run the PO approval process by calling the API
                    The buyer on the PO is used to approved the PO and initialize the PO
                    The Output of this program will give the output on the list of PO's which has been asked for
                    approval
    ***********************************************************************************************************
    Modification History:
    Version   SCN#   By                         Date             Comments

     1.0              Sivakumar Boothathan    27-March-2012           NA
     v1.1         BT Technology Team         29-DEC-2014         Retrofit for BT project
    *********************************************************************/
    /********************************************************************
       procedure to call the program which will pick up the PO Number
       and then approve the same
     ********************************************************************/
    PROCEDURE xxdo_po_approval_prc (errbuf                    OUT VARCHAR2,
                                    retcode                   OUT VARCHAR2,
                                    p_po_number            IN     VARCHAR2,
                                    p_po_line_number       IN     NUMBER,
                                    p_po_shipment_number   IN     NUMBER);
END;
/
