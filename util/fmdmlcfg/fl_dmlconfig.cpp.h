// generated by Fast Light User Interface Designer (fluid) version 1.0308

#include "fl_dmlconfig.h"

static Fl_Double_Window *pDMLConfig=(Fl_Double_Window *)0;

Fl_Check_Browser *pCFGList=(Fl_Check_Browser *)0;

static Fl_Double_Window* MakeConfig() {
  { pDMLConfig = new Fl_Double_Window(SCALE(320), SCALE(240), "T2FMDML Configuration");
    pDMLConfig->callback((Fl_Callback*)OnConfigClose);
    { Fl_Box* o = new Fl_Box(SCALE(5), 0, SCALE(390), SCALE(25), "Configure DML Options:");
      o->labelfont(1);
      o->align(Fl_Align(FL_ALIGN_LEFT|FL_ALIGN_INSIDE));
      o->when(FL_WHEN_NEVER);
    } // Fl_Box* o
    { Fl_Return_Button* o = new Fl_Return_Button(SCALE(200), SCALE(210), SCALE(115), SCALE(25), "Done");
      o->callback((Fl_Callback*)OnConfigDone);
    } // Fl_Return_Button* o
    { pCFGList = new Fl_Check_Browser(SCALE(5), SCALE(25), SCALE(310), SCALE(180));
      pCFGList->callback((Fl_Callback*)OnConfigChanged);
      pCFGList->when(FL_WHEN_CHANGED);
    } // Fl_Check_Browser* pCFGList
    pDMLConfig->set_modal();
    pDMLConfig->end();
  } // Fl_Double_Window* pDMLConfig
  return pDMLConfig;
}
