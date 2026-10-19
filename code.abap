*& Report  ZMM_INVENTORY_PROCESSOR
*& Materials Management (MM) Inventory & Goods Receipt Engine
*& Architecture Pattern: SAP NetWeaver 3-Tier Client-Server Architecture
REPORT zmm_inventory_processor_rep.
*======================================================================*
* 1. DATA DICTIONARY (DDIC) TABLES & STRUCTURAL DECLARATIONS           *
*======================================================================*
* Streamlined to remove unused RBKP and RSEG table declarations
TABLES: mara, mard, mkpf, mseg.
TYPES: BEGIN OF ty_receipt_input,
         matnr TYPE mara-matnr,   " Material Number
         menge TYPE mseg-menge,   " Quantity to Receive
         werks TYPE mseg-werks,   " Target Plant
         lgort TYPE mseg-lgort,   " Target Storage Location
       END OF ty_receipt_input.
*--- Global Storage Allocation Variables
DATA: gs_input    TYPE ty_receipt_input,
      gv_mat_doc TYPE mkpf-mblnr.
*--- Factory Standard BAPI Interface Mappings
DATA: gs_header   TYPE bapi2017_gm_head_01,
      gs_code     TYPE bapi2017_gm_code,
      gs_head_ret TYPE bapi2017_gm_head_ret,
      gt_item     TYPE TABLE OF bapi2017_gm_item_create,
      gs_item     TYPE bapi2017_gm_item_create,
      gt_return   TYPE TABLE OF bapiret2,
      gs_return   TYPE bapiret2.
*======================================================================*
* 2. PRESENTATION LAYER: SELECTION SCREEN DESIGN (USER INTERFACE)       *
*======================================================================*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_matnr TYPE mara-matnr OBLIGATORY,
              p_menge TYPE mseg-menge OBLIGATORY,
              p_werks TYPE mseg-werks OBLIGATORY,
              p_lgort TYPE mseg-lgort OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.
*======================================================================*
* 3. APPLICATION LAYER: LOGICAL VALIDATION DEFINITIONS                 *
*======================================================================*
CLASS lcl_inventory_validator DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      validate_material IMPORTING iv_matnr TYPE mara-matnr
                        RETURNING VALUE(rv_exists) TYPE flag,
     check_storage_path IMPORTING iv_matnr TYPE mara-matnr
                                  iv_werks TYPE mseg-werks
                                  iv_lgort TYPE mseg-lgort
                        RETURNING VALUE(rv_active) TYPE flag.
ENDCLASS.
CLASS lcl_inventory_validator IMPLEMENTATION.
  METHOD validate_material.
    DATA: lv_material TYPE mara-matnr. " Replaced global with clean local memory
    rv_exists = abap_true.
    SELECT SINGLE matnr FROM mara INTO lv_material
      WHERE matnr = iv_matnr.
    IF sy-subrc <> 0.
      rv_exists = abap_false.
    ENDIF.
  ENDMETHOD.
METHOD check_storage_path.
    DATA: lv_unrestrict TYPE mard-labst. " Replaced global with clean local memory
    rv_active = abap_false.
    SELECT SINGLE labst FROM mard INTO lv_unrestrict
WHERE matnr = iv_matnr
        AND werks = iv_werks
        AND lgort = iv_lgort.
 IF sy-subrc = 0.
      rv_active = abap_true.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
*======================================================================*
* 4. PROGRAM CONTROL AND TRANSACTION ENGINE PROCESSING RUNS            *
*======================================================================*
START-OF-SELECTION.
*--- Verification Check 1: Confirm absolute product registry record existence
  IF lcl_inventory_validator=>validate_material( iv_matnr = p_matnr ) = abap_false.
    MESSAGE 'Execution Error: The scanned barcode identifier is invalid in Master Table MARA.' TYPE 'E'.
    EXIT.
  ENDIF.
*--- Verification Check 2: CALL ACTIVATED (Fixed missing validation bug)
  IF lcl_inventory_validator=>check_storage_path( iv_matnr = p_matnr
                                                   iv_werks = p_werks
                                                   iv_lgort = p_lgort ) = abap_false.
    MESSAGE 'Execution Error: Target Plant or Storage Location configuration is structurally inactive in MARD.' TYPE 'E'.
    EXIT.
  ENDIF.
*--- Step 2: Formulate runtime buffer layouts for standard BAPI parameter calls
  gs_header-pstng_date = sy-datum. " Current processing posting day timestamp
  gs_header-doc_date   = sy-datum.
  gs_code-gm_code      = '01'.     " GM Code 01 signals inventory Goods Receipt entries
*--- Simulating raw streaming barcode inputs mapped into internal structures
  gs_item-material  = p_matnr.
  gs_item-entry_qnt = p_menge.
  gs_item-plant     = p_werks.
  gs_item-stge_loc = p_lgort.
  gs_item-move_type = '101'.       " Movement orientation logic code for standard receipts
  APPEND gs_item TO gt_item.
*--- Step 3: Call factory safe routing layer interface to guard core tables
  CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
    EXPORTING
      goodsmvt_header  = gs_header
      goodsmvt_code    = gs_code
    IMPORTING
      goodsmvt_headret = gs_head_ret
    TABLES
      goodsmvt_item    = gt_item
      return           = gt_return.
*--- Step 4: Evaluate returned diagnosis records (Analyzing diagnostic messages)
  DATA: gv_error_flag TYPE flag VALUE abap_false.
  LOOP AT gt_return INTO gs_return WHERE type = 'E' OR type = 'A'.
    gv_error_flag = abap_true.
    WRITE: / 'Diagnostic Error Tracked:', gs_return-message COLOR COL_NEGATIVE.
  ENDLOOP.
  IF gv_error_flag = abap_true.
    " Error state catch: Roll back memory buffers cleanly to protect database health
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    WRITE: / 'Transaction Status: Aborted. All database table updates rolled back safely.'.
  ELSE.
    " Pristine run state: Save changes permanently across database tiers
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.
    gv_mat_doc = gs_head_ret-mat_doc.
WRITE: / 'Transaction Status: Success!',
           / 'New Inventory Log ID Generated:', gv_mat_doc COLOR COL_POSITIVE.
  ENDIF.
