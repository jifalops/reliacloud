part of chart;

/**
 * Code based on charts.js by Nick Downie, http://chartjs.org/
 * 
 * (Partial) Dart implementation done by Symcon GmbH, Tim Rasim
 * 
 */

class Bar extends DartChart {
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
  double barWidth;
  
  Bar(data, config):super(data, config) {
    defaultConfiguration({
      'scaleOverlay' : false,
      'scaleOverride' : false,
      'scaleSteps' : null,
      'scaleStepWidth' : null,
      'scaleStartValue' : 0.0,
      'scaleLineColor' : "rgba(0,0,0,.1)",
      'scaleLineWidth' : 1,
      'scaleShowLabels' : true,
      'scaleLabel' : "<%=value%>",
      'scaleFontFamily' : "'Arial'",
      'scaleFontSize' : 12,
      'scaleFontStyle' : "normal",
      'scaleFontColor' : "#666",
      'scaleShowGridLines' : true,
      'scaleGridLineColor' : "rgba(0,0,0,.05)",
      'scaleGridLineWidth' : 1,
      'barShowStroke' : true,
      'barStrokeWidth' : 2,
      'barValueSpacing' : 5,
      'barDatasetSpacing' : 1,
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
    this.valueBounds = getValueBounds(this.scaleHeight, this.labelHeight);
    //Check and set the scale
    if (!getConfiguration('scaleOverride')){
      this.calculatedScale = calculateScale(this.scaleHeight,this.valueBounds['maxSteps'],this.valueBounds['minSteps'],this.valueBounds['maxValue'],this.valueBounds['minValue']);
    } else {
      this.calculatedScale = {
        'steps' : getConfiguration('scaleSteps'),
        'stepValue' : getConfiguration('scaleStepWidth'),
        'graphMin' : getConfiguration('scaleStartValue'),
        'labels' : []
      };
      populateLabels(this.calculatedScale['labels'],this.calculatedScale['steps'],this.getConfiguration('scaleStartValue'),this.getConfiguration('scaleStepWidth'));
    }
    
    //TODO: add feature to calculate steps and stepValue according to scaleStartValue. I don't see the point to set them manually 
    
    this.scaleHop = (scaleHeight/calculatedScale['steps']).floor();
    calculateXAxisSize();
   
    animationLoop();   
  }
   
  Map<String, num> calculateXAxisSize() {
    double longestText = 1.0;
    //if we are showing the labels
    if (getConfiguration('scaleShowLabels')) {
      this.context.font = getConfiguration('scaleFontStyle').toString() + " " + getConfiguration('scaleFontSize').toString() + "px " + getConfiguration('scaleFontFamily').toString();
      for (int i = 0; i < this.calculatedScale['labels'].length; i++) {
        double measuredText = this.context.measureText(this.calculatedScale['labels'][i]).width;
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
    this.valueHop = (this.xAxisLength / (this.data['labels'].length)).floor();

    this.yAxisPosX = this.width.toDouble() - this.widestXLabel / 2 - this.xAxisLength;
    this.xAxisPosY = this.scaleHeight.toDouble() + getConfiguration('scaleFontSize') / 2;
    this.barWidth = (this.valueHop 
        - getConfiguration('scaleGridLineWidth')*2 
        - getConfiguration('barValueSpacing')*2 
        - (getConfiguration('barDatasetSpacing')*this.data['datasets'].length-1) 
        - ((getConfiguration('barStrokeWidth')/2)*this.data['datasets'].length-1))
        /this.data['datasets'].length;
  }
  

  
  void drawBars(animPc){
    this.context.lineWidth = getConfiguration('barStrokeWidth');
    for (int i=0; i<this.data['datasets'].length; i++){
      this.context.fillStyle = this.data['datasets'][i]['fillColor'];
      this.context.strokeStyle = this.data['datasets'][i]['strokeColor'];
      for (int j=0; j<this.data['datasets'][i]['data'].length; j++){
        //render bar if it's not null
        if (this.data['datasets'][i]['data'][j] != null){
          double barOffset = this.yAxisPosX + getConfiguration('barValueSpacing') + this.valueHop*j + this.barWidth*i + getConfiguration('barDatasetSpacing')*i + getConfiguration('barStrokeWidth')*i;
          this.context.beginPath();
          this.context.moveTo(barOffset, this.xAxisPosY);
          this.context.lineTo(barOffset, this.xAxisPosY - animPc*calculateOffset(this.data['datasets'][i]['data'][j].toDouble(),this.calculatedScale,this.scaleHop)+(getConfiguration('barStrokeWidth')/2));
          this.context.lineTo(barOffset + this.barWidth, this.xAxisPosY - animPc*calculateOffset(this.data['datasets'][i]['data'][j].toDouble(),this.calculatedScale,this.scaleHop)+(this.getConfiguration('barStrokeWidth')/2));
          this.context.lineTo(barOffset + this.barWidth, this.xAxisPosY);
          if(getConfiguration('barShowStroke')){
            this.context.stroke();
          }
          this.context.closePath();
          this.context.fill();
        }
      }
    }
  }
  
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
      }
      else {
        this.context.fillText(this.data['labels'][i], this.yAxisPosX + i * this.valueHop + this.valueHop/2, this.xAxisPosY + getConfiguration('scaleFontSize') + 3);               
      }

      this.context.beginPath();
      this.context.moveTo(this.yAxisPosX + (i+1) * this.valueHop, this.xAxisPosY + 3);
      
      this.context.lineWidth = getConfiguration('scaleGridLineWidth');
      this.context.strokeStyle = getConfiguration('scaleGridLineColor');
      this.context.lineTo(this.yAxisPosX + (i+1) * this.valueHop, 5);
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
    drawBars(animPc);
  }
  
}