Engine_Decimator : CroneEngine {
  var srate=48000, sdepth=31;
  var <synth;
	
  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    SynthDef(\Decimator, {|inL, inR, out, srate=48000, sdepth=31|
      var sound = {
        Decimator.ar(SoundIn.ar([0,1]),
          srate, 
          sdepth
        ); 
      };
      
      Out.ar(out, sound);
    }).add;

    context.server.sync;

    synth = Synth.new(\Decimator, [
      \inL, context.in_b[0].index,			
      \inR, context.in_b[1].index,
      \out, context.out_b.index,
      \srate, 48000,
      \sdepth, 31],
    context.xg);

    this.addCommand("srate", "i", {|msg|
      synth.set(\srate, msg[1]);
    });
    
    this.addCommand("sdepth", "f", {|msg|
      synth.set(\sdepth, msg[1]);
    }); 

  }

  free {
    synth.free;
  }
}