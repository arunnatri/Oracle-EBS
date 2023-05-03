--
-- XXD_MASSADD_PREP_CUST_PKG  (Package) 
--
--  Dependencies: 
--   FA_MASSADD_PREPARE_PKG (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_MASSADD_PREP_CUST_PKG
    AUTHID CURRENT_USER
AS
    /* $Header: XXD_MASSADD_PREP_CUST_PKG.pkb 120.2.12010000.2 2014/10/15 09:44:58 btdev ship

      -- Purpose :
      -- Public function and procedure declarations
    ***************************************************************************************
      Program    : XXD_MASSADD_PREP_CUST_PKG
      Author     :
      Owner      : APPS
      Modifications:
      -------------------------------------------------------------------------------
      Date           version    Author          Description
      -------------  ------- ----------     -----------------------------------------
      15-Oct-2014     1.0     BTDEV        Added custom code called by FA_MASSADD_PREP_CUSTOM_PKG
              to handle merge split functionality.

    ***************************************************************************************/
    PROCEDURE get_splt_mrg_prnt_rec (p_mass_add_rec IN OUT NOCOPY FA_MASSADD_PREPARE_PKG.mass_add_rec, p_location_id IN NUMBER, p_custodian_id IN NUMBER);


    PROCEDURE get_splt_mrg_ch_rec (p_mass_add_rec IN FA_MASSADD_PREPARE_PKG.mass_add_rec, p_location_id IN NUMBER, p_custodian_id IN NUMBER);

    PROCEDURE get_split_records (p_mass_add_rec IN OUT NOCOPY FA_MASSADD_PREPARE_PKG.mass_add_rec, p_location_id IN NUMBER, p_custodian_id IN NUMBER);
END XXD_MASSADD_PREP_CUST_PKG;
/
