/* Short, self-contained PCM cue for the local separation warning. */
#include <windows.h>
#include <math.h>
#include <string.h>

/* The TinyCC Windows SDK does not ship mmeapi.h. */
#pragma pack(push, 1)
typedef struct {
 WORD tag,channels;
 DWORD sample_rate,bytes_per_second;
 WORD block_align,bits,extra_size;
} WaveFormat;
#pragma pack(pop)

typedef struct {
 char *data;
 DWORD length,recorded;
 DWORD_PTR user;
 DWORD flags,loops;
 void *next;
 DWORD_PTR reserved;
} WaveBuffer;

typedef UINT (WINAPI *WaveOpen)(HANDLE*,UINT,const WaveFormat*,DWORD_PTR,DWORD_PTR,DWORD);
typedef UINT (WINAPI *WaveBlock)(HANDLE,WaveBuffer*,UINT);
typedef UINT (WINAPI *WaveDevice)(HANDLE);
static WaveOpen open_wave;
static WaveBlock prepare_wave,write_wave,unprepare_wave;
static WaveDevice reset_wave,close_wave;
static HANDLE device;
static WaveBuffer buffer;
static int prepared;
enum { SAMPLE_RATE=22050, SAMPLE_COUNT=5*SAMPLE_RATE };
static short samples[SAMPLE_COUNT];

static int load_wave(void){
 static HMODULE library;
 if(!library){
  library=LoadLibraryExW(L"winmm.dll",NULL,0x00000800); /* System32. */
  if(!library)return 0;
  open_wave=(WaveOpen)GetProcAddress(library,"waveOutOpen");
  prepare_wave=(WaveBlock)GetProcAddress(library,"waveOutPrepareHeader");
  write_wave=(WaveBlock)GetProcAddress(library,"waveOutWrite");
  unprepare_wave=(WaveBlock)GetProcAddress(library,"waveOutUnprepareHeader");
  reset_wave=(WaveDevice)GetProcAddress(library,"waveOutReset");
  close_wave=(WaveDevice)GetProcAddress(library,"waveOutClose");
 }
 return open_wave&&prepare_wave&&write_wave&&unprepare_wave&&reset_wave&&close_wave;
}

int stop_heartbeat_wave(void){
 if(!device)return 1;
 if(reset_wave(device))return 0;
 if(prepared && unprepare_wave(device,&buffer,sizeof(buffer)))return 0;
 prepared=0;
 if(close_wave(device))return 0;
 device=NULL;
 return 1;
}

static void add_thud(double start,double strength){
 int first=(int)(start*SAMPLE_RATE),length=SAMPLE_RATE*24/100;
 for(int i=0;i<length && first+i<SAMPLE_COUNT;i++){
  double t=(double)i/SAMPLE_RATE;
  double envelope=(1-exp(-180*t))*exp(-22*t);
  double phase=6.28318530718*(70*t-80*t*t);
  double tone=sin(phase)+.32*sin(2*phase)+.12*sin(3*phase);
  samples[first+i]+=(short)(strength*envelope*tone);
 }
}

int play_heartbeat_wave(double volume){
 if(!stop_heartbeat_wave()||!load_wave())return 0;
 if(volume==0)return 1;
 memset(samples,0,sizeof(samples));
 double at=.04,interval=.90;
 while(at<4.75){
  add_thud(at,5700*volume);
  add_thud(at+.19,3450*volume);
  at+=interval;
  interval-=.044;
 }
 WaveFormat format={1,1,SAMPLE_RATE,2*SAMPLE_RATE,2,16,0};
 HANDLE opened=NULL;
 if(open_wave(&opened,(UINT)-1,&format,0,0,0))return 0;
 device=opened;
 memset(&buffer,0,sizeof(buffer));
 buffer.data=(char*)samples;
 buffer.length=sizeof(samples);
 prepared=prepare_wave(device,&buffer,sizeof(buffer))==0;
 if(prepared && !write_wave(device,&buffer,sizeof(buffer)))return 1;
 stop_heartbeat_wave();
 return 0;
}
