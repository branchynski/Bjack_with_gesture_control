/**
 * Module name:   ai_type_pkg
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-30
 * Description:  defining global data types for the AI 
 * gesture recognition system.
 */

package ai_type_pkg;

   typedef enum logic [1:0] {
    NOTHING,
    SWIPE_RIGHT,
    KNOCK
    } gesture_out;

endpackage