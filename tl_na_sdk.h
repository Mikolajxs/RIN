/**
 * @file
 * @brief This is the header file for the Thorlabs Noise Analyzer SDK Library
 * @section Copyright
 * Thorlabs Laser Division, 2021-2024
 */

#ifndef TL_NA_SDK_H
#define TL_NA_SDK_H

////////////////////////////////////includes///////////////////////////////////////////////////////
#include "ftd2xx.h"
#include <stdint.h>
///////////////////////////////////////////////////////////////////////////////////////////////////


//////////////////////////////////////////typedefs/////////////////////////////////////////////////
typedef struct 
{
   FT_HANDLE handle_a;
   FT_HANDLE handle_b;
   uint64_t loc_a;
   uint64_t loc_b;
}NoiseAnalyzer_t;
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////Return codes////////////////////////////////////////////////
enum NA_RC
{
   A_OK,
   TLPNA_INIT_ERR,
   TLPNA_DEV_NOT_FOUND,
   TLPNA_READ_ERR,
   TLPNA_WRITE_ERR,
   TLPNA_SET_TERMINATION_ERR,
   TLPNA_GET_SPECTRUM_ERR,
   TLPNA_COMMS_TIMEOUT,
   TLPNA_SPECTRUM_LENGTH_ERR,
   TLPNA_SPI_WRITE_ERR,
   TLPNA_SPI_READ_ERR,
   TLPNA_CSUM_ERR,
   TLPNA_UNSYNCED_SPECTRUM,
   TLPNA_GET_SN_ERR,
   TLPNA_BUFFER_LEN_ERR,
   TLPNA_CLOSE_ERR,
   TLPNA_SPI_BUFFER_ERR,
   TLPNA_SPI_MALLOC_ERR
};

typedef enum 
{
   RECT_1,
   BLACKMAN_HARRIS,
   BLACKMAN,
   HANNING
}WINDOW_FUNCTION;

typedef enum 
{
   R1M,
   R50K,
   R5K,
   R500,
   R50
}NA_INPUT_TERM;

///////////////////////////////////////////////////////////////////////////////////////////////////

#ifdef _WIN32
   #ifdef EXPORT_TL_NA_SDK
      #define EXTLNASDK __declspec(dllexport)
   #else
      #define EXTLNASDK __declspec(dllimport)
   #endif

   #define CCONV __cdecl
#else 
   // implies Unix / Linux
   #ifdef EXPORT_TL_NA_SDK
      #define EXTLNASDK __attribute__((visibility("default")))
   #else
      #define EXTLNASDK 
   #endif

   #if defined(_UNIX) or defined(_UNIX_ARM8)
      #define CCONV
   #endif
#endif

#ifdef __cplusplus
extern "C"
{
#endif

/*! Enumerates noise analyzer devices connceted via USB. 
 *@param na Pointer to noise analyzer data structure. 
 *@return 0 if no error 
 */
EXTLNASDK int32_t CCONV FindNoiseAnalyzer(NoiseAnalyzer_t* na);

/**
 * Closes the noise analyzer. 
 * @param na Pointer to noise analyzer data structure. 
 * @return 0 if no error
*/
EXTLNASDK int32_t CCONV CloseNoiseAnalyzer(NoiseAnalyzer_t* na);

/** 
 * Initializes noise analyzer USB interface. 
 *@param na Pointer to noise analyzer data structure. 
 *@return 0 if no error 
 */
EXTLNASDK int32_t CCONV InitNoiseAnalyzer(NoiseAnalyzer_t* na);

/**
 * Retrieves Serial Number from the noise analyzer. 
 * @param na Pointer to noise analyzer data structure. 
 * @param sn Output pointer, character array to receive SN. Must be allocated with at least 17 bytes.
 * @return 0 if no error
*/
EXTLNASDK int32_t CCONV GetSerialNumber(NoiseAnalyzer_t* na, char* sn);

/** 
 * Computes real DFT of each segment of time domain data 
 *@param td, Single precision float array of length 8192 
 *@param spectrum, Single precision float array of length 3 * ((8192 / 2) + 1), magnitudes squared
 *@param opts, Options flags, 0 for none, 1 for subtract mean 
 *@return 0 if no error 
 */
EXTLNASDK int32_t CCONV GetSpectrum(float* td, 
                                    float* spectrum, 
                                    WINDOW_FUNCTION win_param, 
                                    int32_t flags);

/** 
 * Retrieves time domain data from USB device 
 *@param na Pointer to a noise analyzer data structure 
 *@param spectrum Array to hold spectrum, must be preallocated to hold 12288 32 bit IEEE-754
 *@return 0 if no error 
 */
EXTLNASDK int32_t CCONV GetTimeDomain(NoiseAnalyzer_t* na, float* spectrum);

/** 
 * Retrieves test signal data from USB device 
 *@param na Pointer to a noise analyzer data structure 
 *@param spectrum Array to hold spectrum, must be preallocated to hold 12288 32 bit IEEE-754
 *@return 0 if no error 
 */
EXTLNASDK int32_t CCONV GetTestSignal(NoiseAnalyzer_t* na, float* spectrum);

/** 
 * Caculates average values of time domain data. 
 *@param data Input, Pointer to first element of an array of time domain data
 *@param avg Output, average value of the contents of data 
 *@return 0 if no error 
 */
EXTLNASDK int32_t CCONV PNACalcAverage(float* spectrum, float* avg);

/**
 * Deprecated.
*/
EXTLNASDK int32_t CCONV SetTermination(NoiseAnalyzer_t* na, NA_INPUT_TERM term);

/**
 * Applies window function to time domain data. 
 * @param io_data Array of floating point time domain samples. 
 * @param len Length of io_data.
 * @param win_param Enum case indicating which window function to apply. Hann is recommended. 
 * @return void
*/
EXTLNASDK void CCONV Window(float* io_data, uint32_t len, WINDOW_FUNCTION win_param);

#ifdef __cplusplus
}
#endif //end Cpp guard

#endif