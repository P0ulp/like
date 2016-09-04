import java.util.Calendar;
import java.util.TimeZone;
import java.io.*;

float valTab[];
int updateTime;
PFont font;
PImage arrow;
color fbc = #3B5998;//#0042d1;//#1f4eb2;//#3B5998;
int dayOfWeek;
int hourOfDay;
Calendar c;
PImage like;
int diffusionTime; 

void setup() {
  size(530, 16);
  this.like = loadImage("facebook-like-icon.png");
  this.arrow = loadImage("arrow.png");
  try {
    this.valTab = float(loadStrings("numbers.txt"));
  }
  catch(Exception e) {
    this.valTab = new float[0];
    println("Number.txt file loading error : "+e);
  }
  this.updateTime = millis();
  this.font = loadFont("SansSerif-10.vlw");
  this.c = Calendar.getInstance(TimeZone.getTimeZone("America/New_York"));
  this.textFont(this.font);
  textAlign(LEFT);
}

void draw() {
  this.dayOfWeek = c.get(Calendar.DAY_OF_WEEK);
  this.hourOfDay = c.get(Calendar.HOUR_OF_DAY);
  if (millis()-this.updateTime > diffusionTime*1000) {
    this.updateTime = millis();
    if (this.dayOfWeek == 1 || this.dayOfWeek == 7 || this.hourOfDay < 8 || this.hourOfDay > 15) {
      drawClosedStock();
    } 
    else {
      drawOpenedStock();
    }
    this.exportPPM();
    this.runPPM(diffusionTime);
  }
  surface.setTitle(int(frameRate) + " fps");
}

private void drawClosedStock() {
  background(0);
  fill(255, 0, 0, 190);
  text("LA BOURSE DE WALL STREET - NYC EST FERMEE", 32, 12);
  fill(fbc);
  diffusionTime = 10000;
  if (this.valTab.length > 0) {
    String textValue = nf(this.valTab[this.valTab.length-1], 0, 3);
    text("A LA CLOTURE", 300, 12);
    image(like, 380, 1);
    text(" = "+textValue+"€", 395, 12);
    diffusionTime = 23;
  }
}

private void drawOpenedStock() {
  background(0);
  boolean updated = this.update();
  if (this.valTab.length > 1 && updated) {
    int curvePosX = 180;
    int graphHeight = 15;
    beginShape();
    stroke(fbc);
    strokeWeight(1.5);
    noFill();
    float moyValue = 0;
    float valMax = sort(this.valTab)[this.valTab.length-1];
    float valMin = sort(this.valTab)[0];
    curveVertex(curvePosX, map(this.valTab[0], valMin, valMax, graphHeight, 1));
    for (int i=0; i<this.valTab.length; i++) {
      moyValue+=this.valTab[i];
      float valP = map(this.valTab[i], valMin, valMax, graphHeight, 1);
      curveVertex(curvePosX+(i*((250-curvePosX)/(this.valTab.length-1.0))), valP);
    }
    moyValue = moyValue / this.valTab.length;
    curveVertex(250, map(this.valTab[this.valTab.length-1], valMin, valMax, graphHeight, 1));
    endShape();
    fill(fbc);
    int s = second();  
    int m = minute();
    int h = hour();
    String textValue = nf(this.valTab[this.valTab.length-1], 0, 3);
    text(nf(h,2)+":"+nf(m,2)+":"+nf(s,2), 30, 12);
    image(like, 85, 1);
    text(" = "+textValue+" €", 98, 12);
    float valDiff = constrain(this.valTab[this.valTab.length-1] - this.valTab[this.valTab.length-2],-moyValue,moyValue);
    valDiff = map(valDiff, moyValue, -moyValue,0,180);
    translate(163, height/2);
    rotate(radians(valDiff));
    translate(-arrow.width/2, -arrow.height/2);
    image(arrow,0,0);
    diffusionTime = 13;
  } 
  else {
    fill(255, 0, 0, 190);
    text("CHARGEMENT EN COURS ...", 32, 12);
    diffusionTime = 10;
  }

}

private boolean update() {
  boolean updated = false;
  String lines[] = loadStrings("http://www.nasdaq.com/symbol/fb/real-time");
  int index = -1;
  String value = "NA";
  float val = 0;
  if (lines != null) {
    for (int i = 0; i < lines.length; i++) {
      index = lines[i].indexOf("id=\"qwidget_lastsale\" class=\"qwidget-dollar\"");
      if (index > -1) {
        value = lines[i].substring(59, 65);
        val = float(value);
        float shares = 2.87; //2.87 billion outstanding share
        float likes = 4.5;//4.5 billion likes a day
        val = (val*shares)/likes; //représente la valeur d'un like par jour
      }
    }
    if (!Float.isNaN(val)) {
      updated = true;
      if (this.valTab.length > 100) {
        this.valTab = reverse(this.valTab);
        this.valTab = shorten(this.valTab);
        this.valTab = reverse(this.valTab);
      }
      this.valTab = append(this.valTab, val);
      saveStrings("numbers.txt", str(this.valTab));
    }
  }
  return updated;
}

private void exportPPM() {
  this.loadPixels();
  byte[] byteImg = new byte[width*height*3];
  for (int i=0; i<width*height; i++) {
    byteImg[3*i] = byte((this.pixels[i] >> 16) & 0xFF);
    byteImg[3*i+1] = byte((this.pixels[i] >> 8) & 0xFF);
    byteImg[3*i+2] = byte(this.pixels[i] & 0xFF);
  }
  try {
    this.writeImage("/home/pi/display16x32/rpi-rgb-led-matrix/testProcessing.ppm", byteImg, width, height);
  }
  catch(IOException e) {
    println(e);
  }
}

private void writeImage(String fn, byte[] data, int width, int height) 
  throws FileNotFoundException, IOException { 
  if (data != null) { 
    FileOutputStream fos = new FileOutputStream(fn); 
    fos.write(new String("P6\n").getBytes()); 
    fos.write(new String(width + " " + height + "\n").getBytes()); 
    fos.write(new String("255\n").getBytes()); 
    fos.write(data); 
    fos.close();
  }
}

private void runPPM(int durationPPM) {
  Runtime rt = Runtime.getRuntime();
  try {
    Process proc = rt.exec("sudo /home/pi/display16x32/rpi-rgb-led-matrix/led-matrix -m 50 -r 16 -t "+durationPPM+" -D 1 /home/pi/display16x32/rpi-rgb-led-matrix/testProcessing.ppm");
    proc.waitFor();
    BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()));
    String s = null;
    while ((s=reader.readLine())!=null) {
      println(s);
    }
  }
  catch(IOException e) {
    println(e);
  }
  catch(InterruptedException e) {
    println(e);
  }
}