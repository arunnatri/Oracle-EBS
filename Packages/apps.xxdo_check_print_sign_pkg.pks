--
-- XXDO_CHECK_PRINT_SIGN_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_CHECK_PRINT_SIGN_PKG
AS
    -- =======================================================================================
    -- NAME: XXDO_CHECK_PRINT_SIGN_PKG.pks
    --
    -- Design Reference:
    --
    -- PROGRAM TYPE :  Package Body
    -- PURPOSE:
    -- For the check prinitng
    -- NOTES
    --
    --
    -- HISTORY
    -- =======================================================================================
    --  Date          Author                                Version             Activity
    -- =======================================================================================
    --
    -- 2-May-2015    BTDev team                                         1.0                  Initial Version
    --
    -- =======================================================================================
    PROCEDURE loadsignature256bit (p_xerrmsg OUT NOCOPY VARCHAR2, p_xerrcode OUT NOCOPY NUMBER, p_signaturename IN VARCHAR2
                                   , p_signaturelocation IN VARCHAR2);

    PROCEDURE fetchsignature256bit (p_clob            IN OUT CLOB,
                                    p_signaturename          VARCHAR);

    PROCEDURE printmessage (p_msgtoken IN VARCHAR2);
END XXDO_CHECK_PRINT_SIGN_PKG;
/
