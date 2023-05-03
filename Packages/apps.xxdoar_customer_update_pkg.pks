--
-- XXDOAR_CUSTOMER_UPDATE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAR_CUSTOMER_UPDATE_PKG"
AS
    /******************************************************************************
    -- NAME:       XXDOAR_CUSTOMER_UPDATE_PKG
    -- PURPOSE:   To define procedures used for customer transmission flag and
    --            contact role update
    -- REVISIONS:
    -- Ver      Date          Author          Description
    -- -----    ----------    -------------   -----------------------------------
    -- 1.0      10-JUL-2016    Infosys         Initial version
    ******************************************************************************/
    --Procedure to update transmission flag
    PROCEDURE xxdoar_upd_transmission_flag;

    --Procedure to Update Contact role
    PROCEDURE xxdoar_update_contact_role;

    --Main procedure
    PROCEDURE main_proc (errbuf                   OUT NOCOPY VARCHAR2,
                         retcode                  OUT NOCOPY NUMBER,
                         p_data_file_name      IN            VARCHAR2,
                         p_control_file_name   IN            VARCHAR2,
                         p_process_type        IN            VARCHAR2);
END XXDOAR_CUSTOMER_UPDATE_PKG;
/
