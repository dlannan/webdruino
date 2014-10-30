int D3;

int D1;

int D2;

void setup()
{
  pinMode(1, INPUT);
}


void loop()
{
  D3 = analogRead(A3);
  D1 = digitalRead(1);
  D2 = D1 + D1;

}