part of chart;

/**
 * Code based on charts.js by Nick Downie, http://chartjs.org/
 * 
 * (Partial) Dart implementation done by Symcon GmbH, Tim Rasim
 * 
 */

abstract class DartChart {
  CanvasElement domNode;

  int width = 0;

  int height = 0;

  CanvasRenderingContext2D context;

  Map config, defaultConfig;

  Map<String, List<Map>> data;
  
  double animFrameAmount = 0.0;
  
  double percentAnimComplete = 0.0;
  
  Animation animation;

  DartChart(Map<String, List<Map>> data, Map config) {
    this.domNode = new CanvasElement();
    this.data = data;

    if (config != null) {
      this.config = config;
    } else {
      //we will use the dafault configuration
      this.config = new Map();
    }
    
    this.context = this.domNode.getContext("2d");  
  }

   /*
   * This function has to be overridden 
   */

  void render() {
  }

  Map calculateScale(int drawingHeight, int maxSteps, int minSteps, double maxValue, double minValue) {
    double graphMin, graphMax, graphRange, stepValue;
    int numberOfSteps, valueRange, rangeOrderOfMagnitude, decimalNum;

    valueRange = maxValue - minValue;

    rangeOrderOfMagnitude = calculateOrderOfMagnitude(valueRange);

    graphMin = (minValue / math.pow(10, rangeOrderOfMagnitude)) * math.pow(10, rangeOrderOfMagnitude).floor();

    graphMax = (maxValue / math.pow(10, rangeOrderOfMagnitude)) * math.pow(10, rangeOrderOfMagnitude).ceil();

    graphRange = graphMax - graphMin;
    
    stepValue = math.pow(10, rangeOrderOfMagnitude).toDouble();

    numberOfSteps = (graphRange / stepValue).round();

    print(stepValue.toString());
    
    //FIXME: this could be the scaling problem
    
    //Compare number of steps to the max and min for that size graph, and add in half steps if need be.
    if (graphRange > 0){
      while (numberOfSteps < minSteps || numberOfSteps > maxSteps) {
        if (numberOfSteps < minSteps) {
          stepValue = stepValue / 2;
          numberOfSteps = (graphRange / stepValue).round();
        } else {
          stepValue = stepValue * 2;
          numberOfSteps = (graphRange / stepValue).round();
        }
      };
    } else {
      stepValue = maxValue;
      numberOfSteps = 1;
    }
      
        
    var labels = [];
    populateLabels(labels, numberOfSteps, graphMin, stepValue);

    return {
        'steps' : numberOfSteps, 
        'stepValue' : stepValue, 
        'graphMin' : graphMin, 
        'labels' : labels
    };

  }

  int calculateOrderOfMagnitude(num val) {
    if (val != 0)
      return (math.log(val) / math.LN10).floor();
    else
      return 1;
  }

//TODO: return result instead of pointer-work?

//Populate an array of all the labels by interpolating the string.

  void populateLabels(List<Object> labels, int numberOfSteps, double graphMin, double stepValue) {
  //Fix floating point errors by setting to fixed the on the same decimal as the stepValue.
    for (int i = 1; i < numberOfSteps + 1; i++) {
      //TODO: is toStringAsFixed really needed?
      //FIXME: Formerly a template engine was used, we might need an alternative.
      labels.add((graphMin + (stepValue * i)).toStringAsFixed(getDecimalPlaces(stepValue)).toString());
    }
  }

  int getDecimalPlaces(double num) {
    if (num % 1 != 0) {
      return num.toString().split(".")[1].length;
    } else {
      return 0;
    }

  }

  void defaultConfiguration(Map defaultConfiguration) {

    this.defaultConfig = defaultConfiguration;

//check if we have too much key in the configuration
    this.config.forEach((String key, value) {
      if (!this.defaultConfig.containsKey(key)) {
        print('Unknown configuration key ' + key);
      }
    });

  }

  getConfiguration(String key) {

    if (!this.defaultConfig.containsKey(key)) {
      print('Invalid configuration key ' + key);
    }

    if (this.config.containsKey(key)) {
      return this.config[key];
    } else {
      return this.defaultConfig[key];
    }

  }

  double calculateOffset(double val, Map calculatedScale, int scaleHop) {
    double outerValue = calculatedScale['steps'] * calculatedScale['stepValue'];
    double adjustedValue = val - calculatedScale['graphMin'];
    double scalingFactor = CapValue(adjustedValue / outerValue, 1.0, 0.0);
    return (scaleHop * calculatedScale['steps']) * scalingFactor;
  }

//Apply cap a value at a high or low number

  double CapValue(double valueToCap, double maxValue, double minValue) {
    if (maxValue != null)if (valueToCap > maxValue) {
      return maxValue;
    }

    if (valueToCap < minValue) {
      return minValue;
    }

    return valueToCap;
  }
  
  Object getValueBounds(int scaleHeight, int labelHeight) {
    double upperValue = double.NEGATIVE_INFINITY;
    double lowerValue = double.INFINITY;
    for (var i = 0; i < this.data['datasets'].length; i++) {
      for (var j = 0; j < this.data['datasets'][i]['data'].length; j++) {
        if (this.data['datasets'][i]['data'][j] != null && this.data['datasets'][i]['data'][j] > upperValue) {
          upperValue = this.data['datasets'][i]['data'][j].toDouble();
        };
        if (this.data['datasets'][i]['data'][j] != null && this.data['datasets'][i]['data'][j] < lowerValue) {
          lowerValue = this.data['datasets'][i]['data'][j].toDouble();
        };
      }
    };

    int maxSteps = (scaleHeight / (labelHeight * 0.66)).floor();
    int minSteps = ((scaleHeight / labelHeight) * 0.5).floor();

    return {
        'maxValue' : upperValue, 'minValue' : lowerValue, 'maxSteps' : maxSteps, 'minSteps' : minSteps
    };

  }
  
  Map<String, int> calculateDrawingSizes(int maxSize,int rotateLabels) {
    maxSize = this.height;
    //Need to check the X axis first - measure the length of each text metric, and figure out if we need to rotate by 45 degrees.
    this.context.font = getConfiguration('scaleFontStyle').toString() + " " + getConfiguration('scaleFontSize').toString() + "px " + getConfiguration('scaleFontFamily');
    int widestXLabel = 1;
    for (int i = 0; i < this.data['labels'].length; i++) {
      double textLength = this.context.measureText(this.data['labels'][i]).width;
      //If the text length is longer - make that equal to longest text!
      widestXLabel = (textLength.round() > widestXLabel) ? textLength.round() : widestXLabel;
    }
    if (this.width / this.data['labels'].length < widestXLabel) {
      rotateLabels = 45;
      if (this.width / this.data['labels'].length < math.cos(rotateLabels) * widestXLabel) {
        rotateLabels = 90;
        maxSize -= widestXLabel;
      } else {
        maxSize -= (math.sin(rotateLabels) * widestXLabel).round();
      }
    } else {
      maxSize -= getConfiguration('scaleFontSize');
    }

    //Add a little padding between the x line and the text
    maxSize -= 5;

    int labelHeight = getConfiguration('scaleFontSize');

    maxSize -= labelHeight.round();
    //Set 5 pixels greater than the font size to allow for a little padding from the X axis.
   
    int scaleHeight = maxSize.toInt();
    //Then get the area above we can safely draw on.
   
    return {
      'labelHeight' : labelHeight,
      'scaleHeight' : scaleHeight,
      'widestXLabel' : widestXLabel
    };
  }
  
  void animateFrame() {
    double easeAdjustedAnimationPercent = (getConfiguration('animation')) ? CapValue(this.animation.getEaseValue(getConfiguration('animationEasing'), this.percentAnimComplete), null, 0.0) : 1.0;
    clear();
    if (getConfiguration('scaleOverlay')) {
      drawChart(easeAdjustedAnimationPercent);
      drawScale();
    } else {
      drawScale();
      drawChart(easeAdjustedAnimationPercent);
    }
  }
  
  void animationLoop() {
    this.animFrameAmount = (getConfiguration('animation')) ? 1 / CapValue(getConfiguration('animationSteps').toDouble(), double.MAX_FINITE, 1.0) : 1.0;
    this.percentAnimComplete = getConfiguration('animation') ? 0.0 : 1.0;
    requestAnimFrame(animLoop);
  }
  
  void animLoop(double time) {
    this.percentAnimComplete += this.animFrameAmount;
    animateFrame();

    //break the recursion when animation is complete
    if (percentAnimComplete <= 1) {
      requestAnimFrame(animLoop);
    } else {
    //FIXME: do the animation complete actions
    }
  }
  
  void clear() {
    this.context.clearRect(0, 0, this.width, this.height);
  }
  
  Object requestAnimFrame(RequestAnimationFrameCallback callback) {
    return window.requestAnimationFrame(callback);
  }
  

  void drawChart(double animPc){    
  }
  
  void drawScale(){    
  }  
  
  void show(Element parentNode){
    this.domNode.width = parentNode.offsetWidth;
    this.domNode.height = parentNode.offsetHeight;

    this.context.canvas.width = this.domNode.width;
    this.context.canvas.height = this.domNode.height;
    this.height = this.domNode.height;
    this.width = this.domNode.width;


    //High pixel density displays - multiply the size of the canvas height/width by the device pixel ratio, then scale.
    if (window.devicePixelRatio != null) {
      this.context.canvas.style.width = this.width.toString() + "px";
      this.context.canvas.style.height = this.height.toString() + "px";
      this.context.canvas.height = (this.context.canvas.height * window.devicePixelRatio).round();
      this.context.canvas.width = (this.context.canvas.width * window.devicePixelRatio).round();
      this.context.scale(window.devicePixelRatio, window.devicePixelRatio);
    }
    
    this.animation = new Animation();
    
    parentNode.children.add(this.domNode);
  }
  
  void hide(){
    this.domNode.remove();
  }
}