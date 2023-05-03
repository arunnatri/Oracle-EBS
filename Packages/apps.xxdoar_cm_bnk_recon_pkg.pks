--
-- XXDOAR_CM_BNK_RECON_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAR_CM_BNK_RECON_PKG"
    AUTHID CURRENT_USER
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  Update Statement Lines Interface for Cash management             *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  02-AUG-2018                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     02-SEP-2016  Infosys Team          Initial Creation                    *
      * 2.0     08-NOV-2018  Srinath Siricilla     Updated Program parameters as part  *
      *                                            of CCR0007490                       *
      * 2.1     20-Aug-2019  Kranthi Bollam        CCR0008128 - Cash Management -      *
      *                                            Transactions not reconciling        *
      *                                            automatically.                      *
      *********************************************************************************/

    -- Commented as part of CCR0007490
    --procedure main
    --( errbuf      out varchar2
    --, retcode     out varchar2);
    -- End of Change
    PROCEDURE main (errbuf                OUT VARCHAR2,
                    retcode               OUT VARCHAR2,
                    p_bank_account     IN     NUMBER              -- Added New
                                                    ,
                    p_statement_from   IN     VARCHAR2            -- Added New
                                                      ,
                    p_statement_to     IN     VARCHAR2            -- Added New
                                                      );

    --Added below procedure for change 2.1
    PROCEDURE upd_main (pv_errbuf OUT VARCHAR2, pn_retcode OUT VARCHAR2, pn_bank_account_id IN NUMBER
                        , pv_statement_from IN VARCHAR2, pv_statement_to IN VARCHAR2, pn_offset_days IN NUMBER DEFAULT 7);
END xxdoar_cm_bnk_recon_pkg;
/
