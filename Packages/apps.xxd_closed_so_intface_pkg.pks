--
-- XXD_CLOSED_SO_INTFACE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_CLOSED_SO_INTFACE_PKG"
AS
    --===================================================================================
    --  PROCEDURE NAME :  Extract_Records_Proc
    --  DESCRIPTION:      Procedure to Extract Sales Order in the staging tables.
    --  Parameters    :   p_Return_Mesg    OUT  Error message
    --                    p_Return_Code    OUT  Error code
    --                    p_from_date      IN   From date to extract the S.O. Data
    --                    p_to_date        IN   Till date to which extract the S.O. Data
    --                    p_data           IN   To group the output as per the selection.
    --===================================================================================
    PROCEDURE extract_records_proc (p_return_mesg OUT VARCHAR2, p_return_code OUT VARCHAR2, p_from_date IN VARCHAR2
                                    , p_to_date IN VARCHAR2, p_data IN VARCHAR2, p_debug IN VARCHAR2 --Latest #BT
                                                                                                    );

    --====================================================================================
    --  PROCEDURE NAME :  derive_update_proc
    --  DESCRIPTION    :  Procedure to perform the required deriviations and
    --                    Updating the Staging table accordingly.
    --  Parameters     :  No Parameters
    --====================================================================================
    PROCEDURE derive_update_proc;

    --====================================================================================
    --  PROCEDURE NAME :  display_quantity_proc
    --  DESCRIPTION    :  Procedure to display the output Aggregated by Price.
    --  Parameters     :  No Parameters
    --====================================================================================
    PROCEDURE display_quantity_proc;

    --====================================================================================
    --  PROCEDURE NAME :  Display_Price_Proc
    --  DESCRIPTION    :  Procedure to display the output Aggregated by Price.
    --  Parameters     :  NA
    --====================================================================================
    PROCEDURE display_price_proc;
END;
/
