void setup()
{
  pinMode(13, OUTPUT);
  pinMode(2, OUTPUT);
  pinMode(3, OUTPUT);
}


void loop()
{
  delay((1000));
  digitalWrite(13,LOW);
  digitalWrite(2,HIGH);
  digitalWrite(3,LOW);
  delay((1000));
  digitalWrite(13,HIGH);
  digitalWrite(2,LOW);
  digitalWrite(3,HIGH);

}