--
-- XXDOAR008_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:11:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoar008_rep_pkg
AS
    /******************************************************************************
       NAME: XXDOAR008_REP_PKG
       PURPOSE:Adjustment Register Report - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        11/17/2010     Shibu        1. Created this package for AR XXDOAR008 Report
    ******************************************************************************/

    --======================================================================+
    --                                                                      |
    -- Report Lexical Parameters                                            |
    --                                                                      |
    --======================================================================+
    p_sql_stmt             VARCHAR2 (32000);
    --======================================================================+
    --                                                                      |
    -- Report Input Parameters                                              |
    --                                                                      |
    --======================================================================+
    p_reporting_level      NUMBER;
    p_reporting_entity     NUMBER;
    p_sob_id               NUMBER;
    p_coa_id               NUMBER;
    p_co_seg_low           VARCHAR2 (50);
    p_co_seg_high          VARCHAR2 (50);
    p_gl_date_low          VARCHAR2 (20);
    p_gl_date_high         VARCHAR2 (20);
    p_currency_code_low    VARCHAR2 (20);
    p_currency_code_high   VARCHAR2 (20);
    p_trx_date_low         VARCHAR2 (20);
    p_trx_date_high        VARCHAR2 (20);
    p_due_date_low         VARCHAR2 (20);
    p_due_date_high        VARCHAR2 (20);
    p_invoice_type_low     VARCHAR2 (40);
    p_invoice_type_high    VARCHAR2 (40);
    p_adj_type_low         VARCHAR2 (40);
    p_adj_type_high        VARCHAR2 (40);
    p_doc_seq_name         VARCHAR2 (200);
    p_doc_seq_low          NUMBER;
    p_doc_seq_high         NUMBER;

    PROCEDURE ar_adj_rep (p_reporting_level      IN            NUMBER,
                          p_reporting_entity     IN            NUMBER,
                          p_sob_id               IN            NUMBER,
                          p_coa_id               IN            NUMBER,
                          p_co_seg_low           IN            VARCHAR2,
                          p_co_seg_high          IN            VARCHAR2,
                          p_gl_date_low          IN            DATE,
                          p_gl_date_high         IN            DATE,
                          p_currency_code_low    IN            VARCHAR2,
                          p_currency_code_high   IN            VARCHAR2,
                          p_trx_date_low         IN            DATE,
                          p_trx_date_high        IN            DATE,
                          p_due_date_low         IN            DATE,
                          p_due_date_high        IN            DATE,
                          p_invoice_type_low     IN            VARCHAR2,
                          p_invoice_type_high    IN            VARCHAR2,
                          p_adj_type_low         IN            VARCHAR2,
                          p_adj_type_high        IN            VARCHAR2,
                          p_doc_seq_name         IN            VARCHAR2,
                          p_doc_seq_low          IN            NUMBER,
                          p_doc_seq_high         IN            NUMBER,
                          retcode                   OUT NOCOPY NUMBER,
                          errbuf                    OUT NOCOPY VARCHAR2);

    TYPE var_t IS RECORD
    (
        p_reporting_level              VARCHAR2 (30),
        p_reporting_entity_id          NUMBER,
        p_sob_id                       NUMBER,
        p_coa_id                       NUMBER,
        p_currency_code_low            VARCHAR2 (15),
        p_currency_code_high           VARCHAR2 (15),
        p_invoice_type_low             VARCHAR2 (50),
        p_invoice_type_high            VARCHAR2 (50),
        p_trx_date_low                 DATE,
        p_trx_date_high                DATE,
        p_due_date_low                 DATE,
        p_due_date_high                DATE,
        p_co_seg_low                   VARCHAR2 (30),
        p_co_seg_high                  VARCHAR2 (30),
        p_adj_acct_low                 VARCHAR2 (240),
        p_adj_acct_high                VARCHAR2 (240),
        p_adj_type_low                 VARCHAR2 (30),
        p_adj_type_high                VARCHAR2 (30),
        p_gl_date_low                  DATE,
        p_gl_date_high                 DATE,
        p_doc_seq_name                 VARCHAR2 (30),
        p_doc_seq_low                  NUMBER,
        p_doc_seq_high                 NUMBER,
        organization_name              VARCHAR2 (50),
        functional_currency_code       VARCHAR2 (15),
        postable                       VARCHAR2 (15),
        adj_currency_code              VARCHAR2 (15),
        cons                           VARCHAR2 (15),
        sortby                         VARCHAR2 (30),
        adj_type                       VARCHAR2 (30),
        trx_number                     VARCHAR2 (36),             --bug4612433
        due_date                       DATE,
        gl_date                        DATE,
        adj_number                     VARCHAR2 (20),
        adj_class                      VARCHAR2 (30),
        adj_type_code                  VARCHAR2 (30),
        adj_type_meaning               VARCHAR2 (30),
        adj_name                       VARCHAR2 (30),
        adj_amount                     NUMBER,
        customer_name                  VARCHAR2 (50),
        customer_number                VARCHAR2 (30),
        customer_id                    NUMBER,
        trx_date                       DATE,
        acctd_adj_amount               NUMBER,
        books_id                       NUMBER,
        chart_of_accounts_id           NUMBER,
        org_name                       VARCHAR2 (50),
        currency_code                  VARCHAR2 (20),
        d_or_i                         VARCHAR2 (6),
        account_code_combination_id    VARCHAR (240),
        debit_account                  VARCHAR (240),
        debit_account_desc             VARCHAR (240),
        debit_balancing                VARCHAR (240),
        debit_balancing_desc           VARCHAR (240),
        debit_natacct                  VARCHAR (240),
        debit_natacct_desc             VARCHAR (240),
        doc_seq_value                  NUMBER,
        doc_seq_name                   VARCHAR (30),
        sql_stmt                       VARCHAR2 (32000)
    );

    var                    var_t;

    FUNCTION before_report
        RETURN BOOLEAN;

    FUNCTION get_trx_requestor (p_trx_id NUMBER, p_col VARCHAR2)
        RETURN VARCHAR2;
END xxdoar008_rep_pkg;
/
