int Distance;

void setup()
{
  pinMode(2, OUTPUT);
  Serial.begin(9600);

}


void loop()
{
  Distance = 0;
  if (Distance <= 100) {
    digitalWrite(2,HIGH);
    Serial.print(("You are close now."));
    Serial.print('\t');

  } else {
    digitalWrite(2,LOW);

  }

}