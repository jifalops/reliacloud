part of chart;

/**
 * Code based on charts.js by Nick Downie, http://chartjs.org/
 * 
 * (Partial) Dart implementation done by Symcon GmbH, Tim Rasim
 * 
 */

class Line extends DartChart {
  int maxSize;
  int scaleHop;
  Map calculatedScale;
  int labelHeight;
  int scaleHeight;
  Map<String, Object> valueBounds;
  int valueHop;
  int widestXLabel;
  double xAxisLength;
  double yAxisPosX;
  double xAxisPosY;
  int rotateLabels = 0;


  Line(data, config):super(data, config) {

    defaultConfiguration({
        'scaleOverlay' : false, 
        'scaleOverride' : false, 
        'scaleSteps' : null, 
        'scaleStepWidth' : null, 
        'scaleStartValue' : null, 
        'scaleLineColor' : "rgba(0,0,0,.1)", 
        'scaleLineWidth' : 1, 
        'scaleShowLabels' : true, 
        'scaleLabel' : "<%=value%>", 
        'scaleFontFamily' : "'Verdana'", 
        'scaleFontSize' : 12, 
        'scaleFontStyle' : "normal", 
        'scaleFontColor' : "#666", 
        'scaleShowGridLines' : true, 
        'scaleGridLineColor' : "rgba(0,0,0,.05)", 
        'scaleGridLineWidth' : 1, 
        'bezierCurve' : true, 
        'pointDot' : true, 
        'pointDotRadius' : 4, 
        'pointDotStrokeWidth' : 2, 
        'datasetStroke' : true, 
        'datasetStrokeWidth' : 2, 
        'datasetFill' : true, 
        'animation' : true, 
        'animationSteps' : 60, 
        'animationEasing' : "easeOutQuart", 
        'onAnimationComplete' : null
    });
  }
  
  void show(Element parentNode){
    super.show(parentNode);
    
    Map<String, int> drawingSizes = calculateDrawingSizes(this.maxSize, this.rotateLabels);
    this.labelHeight = drawingSizes['labelHeight'];
    this.scaleHeight = drawingSizes['scaleHeight'];
    this.widestXLabel = drawingSizes['widestXLabel']; 
    
    valueBounds = getValueBounds(this.scaleHeight, this.labelHeight);

    if (!getConfiguration('scaleOverride')) {
      this.calculatedScale = calculateScale(this.scaleHeight, this.valueBounds['maxSteps'], this.valueBounds['minSteps'], this.valueBounds['maxValue'], this.valueBounds['minValue']);
    } else {
      this.calculatedScale = {
          'steps' : getConfiguration('scaleSteps'), 'stepValue' : getConfiguration('scaleStepWidth'), 'graphMin' : getConfiguration('scaleStartValue'), 'labels' : []
      };
      populateLabels(this.calculatedScale['labels'], this.calculatedScale['steps'], getConfiguration('scaleStartValue'), getConfiguration('scaleStepWidth'));
    }

    this.scaleHop = (this.scaleHeight / (this.calculatedScale['steps'] + 1)).round();
    calculateXAxisSize();
    
    animationLoop();    
  }

  Map<String, num> calculateXAxisSize() {
    double longestText = 1.0;
    //if we are showing the labels
    if (getConfiguration('scaleShowLabels')) {
      this.context.font = getConfiguration('scaleFontStyle').toString() + " " + getConfiguration('scaleFontSize').toString() + "px " + getConfiguration('scaleFontFamily').toString();
      for (int i = 0; i < this.data['labels'].length; i++) {
        double measuredText = this.context.measureText(this.data['labels'][i]).width;
        longestText = (measuredText > longestText) ? measuredText : longestText;
      }
      
      //also calculate the width of the scales, so they won't be cut off.
      for (int i = 0; i < calculatedScale['steps']; i++) {
        double measuredText = this.context.measureText(calculatedScale['labels'][i]).width;
        longestText = (measuredText > longestText) ? measuredText : longestText;
      }
      
      //Add a little extra padding from the y axis
      longestText = longestText + 10;
    }

    this.xAxisLength = this.width.toDouble() - longestText - this.widestXLabel.toDouble();
    this.valueHop = (this.xAxisLength / (this.data['labels'].length - 1)).floor();

    this.yAxisPosX = this.width.toDouble() - this.widestXLabel / 2 - this.xAxisLength;
    
    this.xAxisPosY = this.scaleHeight.toDouble() + getConfiguration('scaleFontSize')/2;
  }
  
  void drawLines(animPc) {
    for (int i = 0; i < this.data['datasets'].length; i++) {
      this.context.strokeStyle = this.data['datasets'][i]['strokeColor'];
      this.context.lineWidth = getConfiguration('datasetStrokeWidth');
      this.context.beginPath();
      
      int lastStartPoint = 0; // point after null-point (needed for null-handling)
      
      if (this.data['datasets'][i]['data'][0] != null){
        this.context.moveTo(this.yAxisPosX, this.xAxisPosY - animPc * (calculateOffset(this.data['datasets'][i]['data'][0].toDouble(), this.calculatedScale, this.scaleHop)));
      }
      
      for (int j = 1; j < data['datasets'][i]['data'].length; j++) {
        //dont do anything, if the point is null
        if (data['datasets'][i]['data'][j] != null){
          //if the last point is null, only move the pencil to the point
          if (data['datasets'][i]['data'][j-1] != null){
            //if this point and the last point are not null, paint the curve
            if (getConfiguration('bezierCurve')) {
              this.context.bezierCurveTo(xPos(j - 0.5), yPos(i, j - 1, animPc), xPos(j - 0.5), yPos(i, j, animPc), xPos(j), yPos(i, j, animPc));
            } else {
              this.context.lineTo(xPos(j), yPos(i, j, animPc));
            }
          } else {
            lastStartPoint = j;
            this.context.moveTo(xPos(j), yPos(i, j, animPc));
          } 
        } else {
          //draw the filling if previous point was not null
          if (data['datasets'][i]['data'][j-1] != null)
            drawDatasetFillWhenConfigured(i,lastStartPoint,j-1);
        }
      }
      
      //if the last point is not null, draw the filling
      if (data['datasets'][i]['data'][this.data['datasets'][i]['data'].length - 1] != null)
        drawDatasetFillWhenConfigured(i,lastStartPoint,this.data['datasets'][i]['data'].length - 1);        
      
      if (getConfiguration('pointDot')) {
        this.context.fillStyle = this.data['datasets'][i]['pointColor'];
        this.context.strokeStyle = this.data['datasets'][i]['pointStrokeColor'];
        this.context.lineWidth = getConfiguration('pointDotStrokeWidth');
        for (var k = 0; k < this.data['datasets'][i]['data'].length; k++) {
          this.context.beginPath();
          if (this.data['datasets'][i]['data'][k] != null)
            this.context.arc(this.yAxisPosX + (this.valueHop * k), this.xAxisPosY - animPc * (calculateOffset(this.data['datasets'][i]['data'][k].toDouble(), this.calculatedScale, this.scaleHop)), getConfiguration('pointDotRadius'), 0, math.PI * 2, true);
          this.context.fill();
          this.context.stroke();
        }
      }
    }
  }
  
  void drawDatasetFillWhenConfigured(int iterator, int lastStartPoint, int activeEndPoint){
    if (getConfiguration('datasetFill')) {
      this.context.stroke();
      
      this.context.strokeStyle = this.data['datasets'][iterator]['fillColor'];
      this.context.lineTo(this.yAxisPosX + (this.valueHop * activeEndPoint), this.xAxisPosY);
      this.context.stroke();
      
      this.context.strokeStyle = "rgba(0,0,0,0)"; //transparent
      this.context.lineTo(this.yAxisPosX + (this.valueHop * lastStartPoint), this.xAxisPosY);
      this.context.stroke();
      
      this.context.closePath();
      this.context.fillStyle = this.data['datasets'][iterator]['fillColor'];
      this.context.fill();
      
      this.context.beginPath();
      this.context.strokeStyle = this.data['datasets'][iterator]['strokeColor'];
    } else {
      this.context.closePath();
      this.context.beginPath();
    }  
  }

  double yPos(dataSet, iteration, animPc) {
    return this.xAxisPosY - animPc * (calculateOffset(this.data['datasets'][dataSet]['data'][iteration].toDouble(), this.calculatedScale, this.scaleHop));
  }

  double xPos(iteration) {
    return this.yAxisPosX + (this.valueHop * iteration);
  }

  //@override
  void drawScale() {
    //X axis line
    this.context.lineWidth = getConfiguration('scaleLineWidth');
    this.context.strokeStyle = getConfiguration('scaleLineColor');
    this.context.beginPath();
    this.context.moveTo(this.width - this.widestXLabel / 2 + 5, this.xAxisPosY);
    this.context.lineTo(this.width - (this.widestXLabel / 2) - this.xAxisLength - 5, this.xAxisPosY);
    this.context.stroke();


    if (this.rotateLabels > 0) {
      this.context.save();
      this.context.textAlign = 'right';
    } else {
      this.context.textAlign = 'center';
    }
    this.context.fillStyle = getConfiguration('scaleFontColor');
    for (var i = 0; i < this.data['labels'].length; i++) {
      this.context.save();
      if (this.rotateLabels > 0) {
        this.context.translate(this.yAxisPosX + i * this.valueHop, this.xAxisPosY + getConfiguration('scaleFontSize'));
        this.context.rotate(-(this.rotateLabels * (math.PI / 180)));
        this.context.fillText(this.data['labels'][i], 0, 0);
        this.context.restore();
      } else {
        this.context.fillText(this.data['labels'][i], this.yAxisPosX + i * this.valueHop, this.xAxisPosY + getConfiguration('scaleFontSize') + 3);
      }

      this.context.beginPath();
      this.context.moveTo(this.yAxisPosX + i * this.valueHop, this.xAxisPosY + 3);

      //Check i isnt 0, so we dont go over the Y axis twice.
      if (getConfiguration('scaleShowGridLines') && i > 0) {
        this.context.lineWidth = getConfiguration('scaleGridLineWidth');
        this.context.strokeStyle = getConfiguration('scaleGridLineColor');
        this.context.lineTo(this.yAxisPosX + i * this.valueHop, 5);
      } else {
        this.context.lineTo(this.yAxisPosX + i * this.valueHop, this.xAxisPosY + 3);
      }
      this.context.stroke();
    }

    //Y axis
    this.context.lineWidth = getConfiguration('scaleLineWidth');
    this.context.strokeStyle = getConfiguration('scaleLineColor');
    this.context.beginPath();
    this.context.moveTo(this.yAxisPosX, this.xAxisPosY + 5);
    this.context.lineTo(this.yAxisPosX, 5);
    this.context.stroke();

    this.context.textAlign = "right";
    this.context.textBaseline = "middle";
    for (int j = 0; j < calculatedScale['steps']; j++) {
      this.context.beginPath();
      this.context.moveTo(this.yAxisPosX - 3, this.xAxisPosY - ((j + 1) * this.scaleHop));
      if (getConfiguration('scaleShowGridLines')) {
        this.context.lineWidth = getConfiguration('scaleGridLineWidth');
        this.context.strokeStyle = getConfiguration('scaleGridLineColor');
        this.context.lineTo(this.yAxisPosX + this.xAxisLength + 5, this.xAxisPosY - ((j + 1) * this.scaleHop));
      } else {
        this.context.lineTo(this.yAxisPosX - 0.5, this.xAxisPosY - ((j + 1) * this.scaleHop));
      }

      this.context.stroke();

      if (getConfiguration('scaleShowLabels')) {
        this.context.fillText(calculatedScale['labels'][j], this.yAxisPosX - 8, this.xAxisPosY - ((j + 1) * this.scaleHop));
      }
    }
  }
  
  //@override
  void drawChart(double animPc){
    drawLines(animPc);
  }

}