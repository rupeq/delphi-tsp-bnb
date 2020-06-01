unit Unit1;
{Разработал Деревяго А. С.
Для курсового проекта}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Grids, ExtCtrls, Menus, Types, math, Unit2, Unit3, Unit4;

const size_vertex=20;
      level_height=80;

type TMatrix=array of array of double;
      TBoolArray=array of boolean;
      TSPProblem=class //класс для решении задачи коммивояжёра
          SG:TStringGrid;//ссылка на таблицу
          img:Timage;//ссылка на холст для рисования
          memo:Tmemo;//ссылка на текстовое окно
          Matrix:TMatrix;//матрица расстояний
          path:string;//опорный путь
          n,col,row:integer;//n - количество путей
          opt:double;//значение опорного решения
          editmode,scrolling:boolean;
          x0,y0,x_click,y_click:integer;
          bmp:TBitmap;
          public   //составляющие интерфейса конструктора
           constructor Create(sg_:TStringGrid;img_:TImage;memo_:Tmemo); //выделяем память под объект
           procedure FindOptPath;//процедура поиска оптимального пути
           procedure OpenFile;//открыть файл
           procedure SaveFile;//сохранить файл
           procedure AddVertex;//добавить пункт
           procedure DeleteVertex; //удалить пункт
          private   //внутренние методы класса
           {overload - переопределение функции для другого набора аргументов}
           procedure DrawVertex(i:integer;x,y,prev_x,prev_y,res:double;color:TColor);overload;//рисовние вершины
           procedure DrawVertex(i:integer;x,y:double);overload;//рисование корневой вершины
           procedure DrawGraph;//рисование графа
           procedure ShowGraph;//рисование графа
           procedure SetEditText(Sender: TObject; ACol, ARow: Integer;const Value: string);
           procedure GetEditText(Sender: TObject; ACol, ARow: Integer;var Value: string);
           procedure KeyDown(Sender: TObject; var Key: Word;Shift: TShiftState);
           procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
           procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
           procedure MouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
           function F0:double;//функция возвращает значение начального опорного решения
           procedure RecFindPath(k,marked_count:integer;res,x,y,dx:double;path_:string;marked:TBoolArray);//рекурсивная процедура поиска пути
      end;

type
  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    N4: TMenuItem;
    N5: TMenuItem;
    N6: TMenuItem;
    N7: TMenuItem;
    Image1: TImage;
    Memo1: TMemo;
    StringGrid1: TStringGrid;
    N8: TMenuItem;
    N9: TMenuItem;
    OpenDialog1: TOpenDialog;
    N10: TMenuItem;
    N11: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure N2Click(Sender: TObject);
    procedure N3Click(Sender: TObject);
    procedure N4Click(Sender: TObject);
    procedure N8Click(Sender: TObject);
    procedure N9Click(Sender: TObject);
    procedure N7Click(Sender: TObject);
    procedure N10Click(Sender: TObject);
    procedure N6Click(Sender: TObject);
    procedure N11Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  problem:TSPProblem; //экземпляр класса

implementation
uses ComObj;

{$R *.dfm}

{ TSPProblem }

{добавляем веришну}
procedure TSPProblem.AddVertex;
var
  i: Integer;
begin
 if (n < 10) then
 begin
    inc(n);
    SG.ColCount:=n;
    SG.RowCount:=n;
    SetLength(Matrix,n,n); //устанавливаем динамический массив n x n
    SG.ColWidths[n-1]:=40;
    for i := 0 to n-1 do
    begin
      SG.Cells[n-1,i]:='0';
      SG.Cells[i,n-1]:='0';
      Matrix[n-1,i]:=0;
      Matrix[i,n-1]:=0;
    end;
    DrawGraph; //рисуем граф по матрице
 end;
end;

{конструктор класса - выделяем память под объект, буфер}
constructor TSPProblem.Create(sg_: TStringGrid; img_: TImage; memo_: TMemo);
var
  i,j: Integer;
begin
  sg:=sg_;
  img:=img_;
  memo:=memo_;
  n:=5;    //стандартно 5х5
  editmode:=false;
  sg.ColCount:=n;
  sg.RowCount:=n;
  SetLength(Matrix,n,n);
  for i := 0 to n-1 do
  begin
    sg.ColWidths[i]:=40;
    for j := 0 to n-1 do
    begin
      Matrix[i,j]:=0;
      SG.Cells[j,i]:='0';
    end;
  end;
  img.Canvas.Brush.Color:=clWhite;
  img.Canvas.FillRect(Rect(0,0,img.Width,img.Height));
  sg.OnSetEditText:=SetEditText;
  sg.OnGetEditText:=GetEditText;
  sg.OnKeyDown:=KeyDown;
  img.OnMouseDown:=MouseDown;
  img.OnMouseup:=MouseUP;
  img.OnMouseMove:=MouseMove;
  scrolling:=false;
  x0:=0;
  y0:=0;
  bmp:=TBitmap.Create;
  bmp.Height:=img.Height*2;
  bmp.Width:=img.Width*10;
  //DrawGraph;
end;

{удаляем вершину}
procedure TSPProblem.DeleteVertex;
begin
  if (n > 3) then
  begin
    dec(n);    //уменьшаем
    SG.ColCount:=n;
    SG.RowCount:=n;
    SetLength(Matrix,n,n); //новый дин. массив
    DrawGraph;     //выводим
  end;
end;

{рисуем вершину}
procedure TSPProblem.DrawVertex(i: integer; x, y, prev_x, prev_y, res:double;color: TColor);
begin   //res - текущая сумма расстояний
  bmp.Canvas.Pen.Color:=ClBlack;//устанвливаем цвет линий чёрным
  bmp.Canvas.MoveTo(round(prev_x + (size_vertex / 2)), round(prev_y + size_vertex));
  bmp.Canvas.LineTo(round(x + (size_vertex / 2)), round(y));//проводим рёбро дерева
  bmp.Canvas.Rectangle(Rect(round(x), round(y), round(x + size_vertex),round(y + size_vertex)));//рисование квадратной вершины дерева
  bmp.Canvas.Font.Color:=color;
  bmp.Canvas.TextOut(round(x + (size_vertex / 4)),round(y + (size_vertex / 4)), IntToStr(i));//подписываем номер вершины
  bmp.Canvas.TextOut(round((prev_x + x)/ 2),round((prev_y + y)/ 2), FloatToStr(res));//подписываем сумарнное расстоние
end;

{рисуем граф}
procedure TSPProblem.DrawGraph;
var i,j:integer;
  x,y,xp,yp,p,q,x0,y0,h,xm,ym,a,xc,yc,r,alpha:double;
  bmp_gr:TBitmap;
begin
  bmp_gr:=TBitmap.Create;//инициализация графического буфера для графа
  bmp_gr.Height:=form2.image2.Height;
  bmp_gr.Width:=form2.image2.Width;
  bmp_gr.Canvas.Pen.Color:=ClBlack;
  {-----------------изменяем положение------------------}
  x0:=bmp_gr.Width/2;  //центр
  y0:=bmp_gr.Height/2; //графического буфера
  r:=200;//и радиус кругового графа
  h:=(2*pi)/n;   //угловое расстояние между вершинами графа
  alpha:=pi/1.25;//радианная мера дуги
  {----------------------рисуем граф-----------------------}
  for i:=0 to n-1 do  //рисуем от вершины i к j
    for j:=0 to n-1 do
    begin
      if((i<>j) and (Matrix[i,j]<>Infinity))  then //если не бесконечность
      begin  //если бесконечность ребро не рисуем
        x:=x0+r*cos(i*h)+size_vertex/2;     //координаты центра 1в
        y:=y0+r*sin(i*h)+size_vertex/2;
        xp:=x0+r*cos(j*h)+size_vertex/2;  //координаты центра 2в
        yp:=y0+r*sin(j*h)+size_vertex/2;
        xc:=(x+xp)/2;
        yc:=(y+yp)/2;
        p:=xp-x;  //вектор нормали к дуге
        q:=yp-y;
        a:=sqrt(p*p+q*q)/(2*cos(alpha/2));  //расстояние между центром окружности
        //d:=asqrt(p*p+q*q)/2;        //дуги и серединой между вершинами
        //xm:=q*sqrt(3)/2+xc;ym:=-p*sqrt(3)/2+yc;
        xm:=(q/2)*Cot((pi-alpha)/2)+xc;  //центр окружности дуги
        ym:=-(p/2)*Cot((pi-alpha)/2)+yc;
        bmp_gr.Canvas.Arc(round(xm-a),round(ym-a),round(xm+a),round(ym+a), round(x),round(y),round(xp),round(yp));  //рисуем дугу
        bmp_gr.Canvas.TextOut(round(xc+(q/40)*Cot((pi/2-alpha)/2)-5),round(yc-(p/40)*Cot((pi/2-alpha)/2)-5),FloatToStr(Matrix[i,j]));//подпись дуги
        //bmp_gr.Canvas.MoveTo(round(x),round(y));
        //bmp_gr.Canvas.LineTo(round(xp),round(yp));
      end;
    end;
  for i:=0 to n-1 do //рисуем вершины
  begin
    x:=x0+r*cos(i*h);
    y:=y0+200*sin(i*h);
    bmp_gr.Canvas.Ellipse(Rect(round(x),round(y),round(x+size_vertex),round(y+size_vertex)));//рисование вершины
    bmp_gr.Canvas.TextOut(round(x+(size_vertex/4)),round(y+(size_vertex/4)),IntToStr(i+1))//подпись вершины
  end;
  form2.image2.Canvas.Draw(0,0,bmp_gr);
end;

{рисуем корневую вершину на дереве}
procedure TSPProblem.DrawVertex(i: integer; x, y:double);
begin
  bmp.Canvas.Pen.Color:=ClBlack;
  bmp.Canvas.Rectangle(Rect(round(x),round(y),round(x+size_vertex),round(y+size_vertex)));
  bmp.Canvas.TextOut(round(x+(size_vertex/4)),round(y+(size_vertex/4)),IntToStr(i))
end;

{ищем начальный опорный путь}
function TSPProblem.F0: double;
var sum:double;
  i,next,next1: Integer;
begin
  sum:=0;
  path:=path+'1-';  //для вывода
  for i := 0 to n-1 do
  begin
    next:=(i+1) mod n;
    sum:=sum + Matrix[i,next];
    next1:=(next+1);
    path:=path+IntToStr(next1)+'-';  //строим и выводим
  end;
  path:=copy(path,0,length(path)-1);
  result:=sum;  //получаем опорный путь
end;

{оптимальный путь}
procedure TSPProblem.FindOptPath;
var marked:TBoolArray; //массив пройденных вершин
    i:integer;
begin
  x0:=(img.Width div 2)-(bmp.width div 2);
  y0:=0;
  img.Canvas.Brush.Color:=clWhite;
  img.Canvas.FillRect(Rect(0,0,img.Width,img.Height));
  memo.Text:='';
  opt:=f0;//начальное опорное решение (вызыв функции)
  SetLength(marked,n-1);//инициализация массива пройденных вершин
  for i := 0 to n-2 do
    marked[i]:=false;
  //FillChar(marked,n-1,0);
  DrawVertex(1,bmp.Width/2,10); //рисование корневой вершины
  memo.Text:=memo.Text+'В качестве опорного решения будет путь: '+path; //выводимв в memo принятые решения
  memo.Text:=memo.Text+#13#10+'Расстояние опорного пути: '+FloatTostr(opt);
  {{----------------изменяем 410---------------------------}
  RecFindPath(0,0,0,bmp.Width/2,10,410,'1-',marked);//рекурсивный поиск оптимального пути
  img.Canvas.Draw(x0,y0,bmp);//копирование из графического буфера
  memo.Text:=memo.Text+#13#10+'Оптимальный путь: '+path+#13#10+'Оптимальное расстояние: '+FloatTostr(opt);
end;

{для изменения текста}
procedure TSPProblem.GetEditText(Sender: TObject; ACol, ARow: Integer;var Value: string);
begin
  editmode:=true;
  col:=ACol;
  row:=ARow;
end;

procedure TSPProblem.KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (key=Vk_return) then  //enter
  begin
    editmode:=false;
    SG.Cells[Col, Row]:=FloatTostr(Matrix[Row,Col]);
    DrawGraph;
  end;
end;

procedure TSPProblem.MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  scrolling:=true; //скролл по дереву
  x_click:=x;        //изменяем координаты
  y_click:=y;
end;

procedure TSPProblem.MouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
  var dx,dy:integer;
begin
  if (scrolling) then //для прокрутки
  begin
    dx:=x-x_click;
    dy:=y-y_click;
    x_click:=x;y_click:=y;
    x0:=x0+dx;
    y0:=y0+dy;
    img.Canvas.FillRect(Rect(0,0,img.Width,img.Height));
    img.Canvas.Draw(x0,y0,bmp);
    //form1.label1.caption:=x0.ToString+' '+y0.ToString;
  end;
end;

procedure TSPProblem.MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  scrolling:=false;
end;

{открытие файла}
procedure TSPProblem.OpenFile;
var OD:TOpenDialog;
  filename:string;
  F:File of double;
  i,j: Integer;
  p:double;
begin
  OD:=TOpenDialog.Create(nil);
  OD.InitialDir:=extractfilepath(Application.ExeName);
  {------------для txt/dat------------}
  OD.Filter:='Матрица(*.txt)|*.txt';
  //OD.Filter:='Матрица(*.dat)|*.dat';
  if Not(OD.Execute) then
    Exit;
  filename:=OD.FileName;
  AssignFile(F,Filename);
  Reset(F);
  read(F,p);
  n:=round(p);
  SG.ColCount:=n;
  SG.RowCount:=n;
  SetLength(Matrix,n,n);
  for i := 0 to n-1 do
  begin
    for j := 0 to n-1 do
    begin
      read(F,Matrix[i,j]);
      SG.Cells[j,i]:=FloatToStr(Matrix[i,j]);
    end;
  end;
  Close(F);
end;

{рекурсивный поиск пути}
procedure TSPProblem.RecFindPath(k, marked_count: integer; res, x, y, dx: double; path_: string; marked: TBoolArray);
var f,x_new,y_new,new_res:double;
  clr:TColor;
  p,i,j:integer;
  right_path:boolean; //правильный путь
  new_marked:TBoolArray;//массив пройденных вершин
begin
  if(marked_count = n - 1) then//если построен гамильтонов маршрут
  begin
    f:=res + Matrix[k,0];
    x_new:=x;
    y_new:=level_height+y;
    clr:=ClGreen;
    if(f < opt) then //если значение гамильтонового пути меньше опорного
    begin
      opt:=f;
      path:=path_+'1';
      memo.Text:=memo.Text+#13#10+'Новый опорный путь: '+path;
      memo.Text:=memo.Text+#13#10+'Расстояние опорного пути: '+FloatToStr(opt)+#13#10;
    end
    else
    begin
      memo.Text:=memo.Text+#13#10+'Расстояние пути: ('+path_+'1) равно '+FloatToStr(f)+'>='+FloatToStr(opt)+#13#10;
      clr:=ClRed; //для дерева помечаем красным
    end;
    DrawVertex(1,x_new,y_new,x,y,f,clr);
  end
  else //построение гамильтоновых путей
  begin
    p:=0;
    for i := 1 to n-1 do
    begin
      new_res:=res+Matrix[k,i];//суммирование с пройденно вершиной
      right_path:=new_res < Opt;//проверка на оптимальность неполного пути
      clr:=clBlack;
      x_new:=(x-dx*(n-marked_count-2)/2)+p*dx;
      y_new:=level_height+y;
      if(not(right_path) and not(marked[i-1])) then//если значение неполного пути меньше опорного, то происходит переход к следущей ветке
      begin
        memo.Text:=memo.Text+#13#10+'Расстояние неполного пути ('+path_+IntToStr(i+1)+') равно '+FloatToStr(new_res)+'>='+FloatToStr(opt)+#13#10;
        clr:=ClRed; //помечаем красным
        DrawVertex(i+1,x_new,y_new,x,y,new_res,clr);//рисование красным цветом неудачной путь
        inc(p);
      end;
      if(right_path and not(marked[i-1]))then//если путь пока правильный, продолжается построение по ветке
      begin
        SetLength(new_marked,n-1);
        for j := 0 to n-2 do
          new_marked[j]:=marked[j];
        new_marked[i-1]:=true;
        DrawVertex(i+1,x_new,y_new,x,y,new_res,clr);
        RecFindPath(i,marked_count+1,new_res,x_new,y_new,dx/3,path_+IntToStr(i+1)+'-',new_marked);//продолжаем поиск оптимального пути
        p:=p+1;
      end;
    end;
  end;
end;

procedure TSPProblem.SaveFile;
var SD:TSaveDialog;
  filename:string;
  F:File of double;
  i,j: Integer;
  p:double;
begin
  SD:=TSaveDialog.Create(nil);
  SD.InitialDir:=extractfilepath(Application.ExeName);
  {------------для txt/dat------------}
  SD.Filter:='Матрица(*.txt)|*.txt';
  //SD.Filter:='Матрица(*.dat)|*.dat'; вариант замены
  if Not(SD.Execute) then
    Exit;
  filename:=SD.FileName;
  AssignFile(F,Filename+'.txt');
  ReWrite(F);
  p:=n;
  Write(F, p);
  for i := 0 to n-1 do
  begin
    for j := 0 to n-1 do
    begin
      write(F,Matrix[i,j]);
    end;
  end;
  Close(F);
end;

procedure TSPProblem.SetEditText(Sender: TObject; ACol, ARow: Integer;const Value: string);
begin
  if(editmode) then
  begin
    if(SG.Cells[ACol, ARow]='00') then //задаем 00 как inf
    begin
        Matrix[ARow,ACol]:=infinity;
    end
    else
      TryStrToFloat(SG.Cells[ACol, ARow],Matrix[ARow,ACol]);
    //SG.Cells[ACol, ARow]:=Matrix[ARow,ACol].ToString;
    //Exit;
  end
  else
    SG.Cells[ACol, ARow]:=FloatToStr(Matrix[ARow,ACol]);
   //editmode:=false;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  problem:=TSPProblem.Create(stringgrid1,image1,memo1);
//form2.Image2.Refresh;
end;

{-----функциональные кнопки-------}
procedure TForm1.N2Click(Sender: TObject);
begin
  problem.OpenFile;
end;

procedure TForm1.N3Click(Sender: TObject);
begin
  problem.SaveFile;
end;

procedure TForm1.N4Click(Sender: TObject);
begin
  close;
end;

procedure TForm1.N8Click(Sender: TObject);
begin
  problem.AddVertex;
end;

procedure TForm1.N9Click(Sender: TObject);
begin
  problem.DeleteVertex;
end;

procedure TForm1.N7Click(Sender: TObject);
begin
  problem.FindOptPath;
end;

procedure TForm1.N10Click(Sender: TObject);
begin
  problem.ShowGraph;
end;

procedure TSPProblem.ShowGraph;
begin
  Form2.Show;
  DrawGraph;
end;

procedure TForm1.N6Click(Sender: TObject);
begin
  Form3.ShowModal;
end;

procedure TForm1.N11Click(Sender: TObject);
begin
  AboutBox.ShowModal;
end;

end.
