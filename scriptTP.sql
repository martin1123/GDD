USE [GD1C2017]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON

-- =======================================================================
-- Author:		Martin Maccio
-- Create date: 25/05/2017
-- Description:	Trigger que verifica que no se de de alta mas de un viaje
--              en el mismo momento para un mismo cliente.
-- =======================================================================
CREATE TRIGGER T_VIAJE_CLIENTE ON SAPNU_PUAS.VIAJE INSTEAD OF INSERT
AS 
BEGIN
	--SE CORROBORA QUE EL VIAJE A INSERTAR NO SE HAYA REALIZADO EN UN MOMENTO EN EL CUAL EL CLIENTE REALIZO OTRO VIAJE
	--TAMBIEN SE CORROBORA QUE LA HORA DE INICIO Y DE FIN DEL VIAJE ESTEN INCLUIDAS DENTRO DEL TURNO CORRESPONDIENTE.
	IF(EXISTS(SELECT * 
				 FROM INSERTED A, SAPNU_PUAS.VIAJE B, SAPNU_PUAS.TURNO C
			    WHERE A.Viaje_Cliente = B.Viaje_Cliente
				  AND A.Viaje_Turno = C.Turno_Codigo
			      AND ((SELECT DATEPART(HOUR, A.Viaje_Fecha_Hora_Inicio)) NOT BETWEEN C.Turno_Hora_Inicio AND C.Turno_Hora_Fin
					   OR (SELECT DATEPART(HOUR, A.Viaje_Fecha_Hora_Fin)) NOT BETWEEN C.Turno_Hora_Inicio AND C.Turno_Hora_Fin
					   OR A.Viaje_Fecha_Hora_Inicio BETWEEN B.Viaje_Fecha_Hora_Inicio AND B.Viaje_Fecha_Hora_Fin
					   OR A.Viaje_Fecha_Hora_Fin BETWEEN B.Viaje_Fecha_Hora_Inicio AND B.Viaje_Fecha_Hora_Fin)))
	BEGIN
	--SE RECHAZA VIAJE
		PRINT('Las horas de inicio y fin a insertar no son válidas. Corroborar que el inicio y fin del viaje sea dentro del mismo turno, y que para un mismo cliente no exista mas de un viaje en el mismo momento.');
		ROLLBACK;
	END
	ELSE
	BEGIN
	--SI SE REALIZA VIAJE EN UNA FRANJA HORARIA DISPONIBLE SE REALIZA EL ALTA DEL VIAJE
		INSERT INTO SAPNU_PUAS.Viaje (VIAJE_CANT_KILOMETROS,VIAJE_FECHA_HORA_INICIO,VIAJE_FECHA_HORA_FIN,VIAJE_CHOFER,VIAJE_AUTO,VIAJE_TURNO,VIAJE_CLIENTE) 
		SELECT VIAJE_CANT_KILOMETROS, VIAJE_FECHA_HORA_INICIO, VIAJE_FECHA_HORA_FIN, VIAJE_CHOFER, VIAJE_AUTO, VIAJE_TURNO, VIAJE_CLIENTE FROM INSERTED;
	END;
END;

GO

-- =======================================================================
-- Author:		Martin Maccio
-- Create date: 11/05/2017
-- Description:	Funcion que verifica que la patente recibida por parametro 
--				no exista en la tabla de Auto
-- =======================================================================
CREATE FUNCTION [SAPNU_PUAS].[verificar_patente] 
(

	@patente VARCHAR(10) 
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	SET @Result = (SELECT COUNT(*) 
					FROM SAPNU_PUAS.Auto
				   WHERE Auto_Patente = @patente); 


	RETURN @Result

END
;

GO
-- ==================================================================================
-- Author:		Maccio Martin
-- Create date: 09/05/2017
-- Description:	Funcion que verifica si un rango horario esta disponible en la tabla 
--              de turnos sin tener en cuenta el turno a modificar. 
--              Devuelve 0 si esta disponible, caso contrario devuelve distinto de 0.
-- ==================================================================================
CREATE FUNCTION[SAPNU_PUAS].[is_available_hour_range]
(
	@iniHour int,
	@endHour int,
	@cod     int = -1 --Parametro que toma -1 como default
)
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Verifica si hay algun turno que se superponga con los horarios ingesados por parametro
	set @Result = (SELECT COUNT(*)
	                 FROM SAPNU_PUAS.turno
				    WHERE Turno_Activo = 1
					  AND Turno_Codigo <> @cod
					  AND ((turno_hora_inicio <= @iniHour AND  @iniHour <  turno_hora_fin)
					       OR (turno_hora_inicio <  @endHour AND  @endHour <= turno_hora_fin)
					       OR (@iniHour <= turno_hora_inicio AND turno_hora_inicio < @endHour)
					       OR (@iniHour < turno_hora_fin AND turno_hora_fin <= @endHour)))

	-- Return the result of the function
	RETURN @Result

END;


GO
-- =============================================
-- Author:		Martin Maccio
-- Create date: 09/05/2017
-- Description:	SP que da de alta un turno
-- =============================================
CREATE PROCEDURE [SAPNU_PUAS].[sp_turno_alta]
	-- Add the parameters for the stored procedure here
	@horaInicio int,
	@horaFin int,
	@descripcion varchar(255),
	@valorkm numeric(18,2),
	@precioBase numeric(18,2),
	@activo  int,
	@codOp   int OUT,
	@resultado  varchar(255) OUT
AS
BEGIN
	DECLARE @validHora int

	SET NOCOUNT ON;
	
    SET @validHora = SAPNU_PUAS.is_available_hour_range(@horaInicio,@horaFin, default);

	--Se valida que no haya ningun turno con el que se superpongan los horarios
	IF(@validHora = 0)
	BEGIN
		BEGIN TRY
			SET @codOp = 0;
			INSERT INTO SAPNU_PUAS.turno
			VALUES(@horaInicio,@horaFin,@descripcion,@valorkm,@precioBase,@activo);
		END TRY
		BEGIN CATCH
			SET @codOp = @@ERROR;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al realizar INSERT en la tabla Turnos';
		END CATCH;
	END
	ELSE
	BEGIN
	--Se encuentran turnos con horarios superpuestos, entonces se envía un mensaje indicando dicho suceso
		SET @codOp = 1;
		SET @resultado = 'Se superponen los horarios con otro/s turno/s';
	END;
END;

GO
-- =============================================
-- Author:		Martin Maccio
-- Create date: 09/05/2017
-- Description:	SP que da de alta un turno
-- =============================================
CREATE PROCEDURE [SAPNU_PUAS].[sp_turno_modif]
	-- Add the parameters for the stored procedure here
	@codigo int,
	@horaInicio int,
	@horaFin int,
	@descripcion varchar(255),
	@valorkm numeric(18,2),
	@precioBase numeric(18,2),
	@activo  int,
	@codOp   int OUT,
	@resultado  varchar(255) OUT
AS
BEGIN
	DECLARE @validHora int

	SET NOCOUNT ON;
	
    SET @validHora = SAPNU_PUAS.is_available_hour_range(@horaInicio,@horaFin,@codigo);

	--Se valida que no haya ningun turno con el que se superpongan los horarios
	IF(@validHora = 0)
	BEGIN
		BEGIN TRY
			SET @codOp = 0;
			UPDATE SAPNU_PUAS.turno
			SET Turno_Hora_Inicio = @horaInicio,
				Turno_Hora_Fin = @horaFin,
				Turno_Descripcion = @descripcion,
				Turno_Valor_Kilometro =  @valorkm,
				Turno_Precio_Base = @precioBase,
				Turno_Activo =  @activo
			WHERE Turno_codigo =  @codigo;
		END TRY
		BEGIN CATCH
			SET @codOp = @@ERROR;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al actualizar los datos de la tabla Turnos';
		END CATCH;
	END
	ELSE
	BEGIN
	--Se encuentran turnos con horarios superpuestos, entonces se envía un mensaje indicando dicho suceso
		SET @codOp = 1;
		SET @resultado = 'Se superponen los horarios con otro/s turno/s';
	END;
END;

GO
-- ==============================================================================
-- Author:		Martin Maccio
-- Create date: 11/05/2017
-- Description:	SP que realiza alta de un automovil.
--              En caso de ser exitosa el alta retorna 0, en caso contrario
--              retornara un codigo de error y un mensaje descriptivo del error.
-- ==============================================================================
CREATE PROCEDURE [SAPNU_PUAS].[sp_auto_alta] 

	@marca int, 
	@modelo varchar(255), 
	@patente varchar(10), 
	@licencia varchar(26), 
	@rodado varchar(10), 
	@activo int, 
	@chofer numeric(18,0), 
	@turno int,
	@codOp int out,
	@resultado varchar(255) out
AS
BEGIN
	DECLARE @validDuplicado int

	SET @validDuplicado = SAPNU_PUAS.verificar_patente(@patente);

	IF(@validDuplicado = 0)
	BEGIN
		BEGIN TRY
			SET @codOp = 0;
			IF(EXISTS(SELECT Auto_Chofer FROM SAPNU_PUAS.AUTO WHERE Auto_Chofer = @chofer AND Auto_Activo = 1))
			BEGIN
				SET @codOp = 2;
				SET @resultado = 'Ya existe un auto activo registrado para el chofer ingresado';
			END
			ELSE
			BEGIN
				INSERT INTO [SAPNU_PUAS].Auto
				VALUES(@marca,@modelo,@patente,@licencia,@rodado,@activo,@chofer,@turno);
			END
		END TRY
		BEGIN CATCH
			SET @codOp = @@ERROR;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al realizar INSERT en la tabla Auto';
		END CATCH
	END
	ELSE
	BEGIN
	--Se encuentra otro auto con la misma patente en la base de datos
		SET @codOp = 1;
		SET @resultado = 'Ya existe un auto con la patente ingresada. Verifique que la patente ingresada sea correcta.';
	END;

END;

GO
-- ========================================================
-- Author:		Martin Maccio
-- Create date: 11/05/2017
-- Description:	SP que realiza la modificacion de los Autos
-- ========================================================
CREATE PROCEDURE [SAPNU_PUAS].[sp_auto_modif]
	@marca int, 
	@modelo varchar(255), 
	@patente varchar(10), 
	@patente_nueva varchar(10),
	@licencia varchar(26), 
	@rodado varchar(10), 
	@activo int, 
	@chofer numeric(18,0), 
	@turno int,
	@codOp int out,
	@resultado varchar(255) out
AS
BEGIN
	DECLARE @validDuplicado int,
			@choferAutos int
	SET NOCOUNT ON;
	SET @validDuplicado = 0;

	IF(@patente <> @patente_nueva)
		SET @validDuplicado = SAPNU_PUAS.verificar_patente(@patente_nueva);

	IF(@validDuplicado = 0)
	BEGIN
		--Se verifica que un auto no tenga asignado un chofer que ya tenga un coche activo. Esta verificacion sirve en caso de que se cambie el chofer del auto.
		--Se agrega la validación contra la patente(vieja en caso de que se haya modificado por una nueva), para que se excluya de la busqueda el registro que se esta alterando. 
		IF(EXISTS(SELECT Auto_Chofer FROM SAPNU_PUAS.AUTO WHERE Auto_Chofer = @chofer AND Auto_Activo = 1 AND Auto_Patente <> @patente))
		BEGIN
			SET @codOp = 2;
			SET @resultado = 'Ya existe un auto activo registrado para el chofer ingresado';
		END
		ELSE
		BEGIN
			BEGIN TRY
				SET @codOp = 0;
				UPDATE SAPNU_PUAS.Auto
				SET Auto_Marca = @marca,
					Auto_Modelo = @modelo,
					Auto_Licencia = @licencia,
					Auto_Rodado = @rodado,
					Auto_Activo = @activo,
					Auto_Chofer = @chofer,
					Auto_turno = @turno,
					Auto_patente = @patente_nueva
				WHERE Auto_Patente =  @patente;
			END TRY
			BEGIN CATCH
				SET @codOp = @@ERROR;
		
				IF(@codOp <> 0)
					SET @resultado = 'Ocurrio un error al actualizar los datos de la tabla Auto';
			END CATCH;
		END;
	END
	ELSE
	BEGIN
	--Se encuentra otro auto con la misma patente en la base de datos
		SET @codOp = 1;
		SET @resultado = 'Ya existe un auto con la patente ingresada. Verifique que la patente ingresada sea correcta.';
	END;
END;

GO

CREATE FUNCTION [SAPNU_PUAS].[exist_car]
(
	@PATENTE varchar(10)
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM SAPNU_PUAS.Auto
		   WHERE Auto_Patente = @PATENTE);

END;

GO

CREATE FUNCTION [SAPNU_PUAS].[exist_chofer]
(
	@DNI numeric(18)
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM SAPNU_PUAS.Chofer
		   WHERE Chofer_Dni = @DNI);

END;

GO

CREATE FUNCTION [SAPNU_PUAS].[exist_turn]
(
	@TURNO int
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM SAPNU_PUAS.Turno
		   WHERE Turno_Codigo = @TURNO);

END;

GO

CREATE FUNCTION [SAPNU_PUAS].[exist_client]
(
	@CLIENT_TEL numeric(18)
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM SAPNU_PUAS.Cliente
		   WHERE Cliente_Telefono = @CLIENT_TEL);

END;

GO

CREATE PROCEDURE [SAPNU_PUAS].[sp_viaje_alta] 
	-- Add the parameters for the stored procedure here
	 @viaje_cant_km numeric(18), 
	 @viaje_hora_ini datetime,
	 @viaje_hora_fin datetime,
	 @viaje_chofer numeric(18),
	 @viaje_auto varchar(10),
	 @viaje_turno int,
	 @viaje_cliente numeric(18),
	 @codOp   int OUT,
	 @resultado  varchar(255) OUT
AS
BEGIN
	SET NOCOUNT ON;
	SET @codOp = 0;
	--Verifica que el viaje se realice dentro del mismo día
	IF((SELECT DATEPART(DAY, @viaje_hora_ini)) <> (SELECT DATEPART(DAY, @viaje_hora_fin)))
	BEGIN
		SET @codOp = 1;
		SET @resultado = 'La hora de inicio y fin del viaje deben corresponder al mismo día.';

	END
	ELSE IF(SAPNU_PUAS.exist_car(@viaje_auto) = 0)
	BEGIN
		SET @codOp = 2;
		SET @resultado = 'No existe un auto activo con la patente ingresada';
	END
	ELSE IF(SAPNU_PUAS.exist_chofer(@viaje_chofer) = 0)
	BEGIN
		SET @codOp = 3;
		SET @resultado = 'El chofer ingresado no se encuentra activo en el sistema';
	END
	ELSE IF(SAPNU_PUAS.exist_turn(@viaje_turno) = 0)
	BEGIN
		SET @codOp = 4;
		SET @resultado = 'No existe el turno ingresado';
	END
	ELSE IF(SAPNU_PUAS.exist_client(@viaje_cliente) = 0)
	BEGIN
		SET @codOp = 5;
		SET @resultado = 'El cliente ingresado no se encuentra registrado';
	END;

	IF (@codOp = 0)
	BEGIN
		BEGIN TRY
			INSERT INTO SAPNU_PUAS.Viaje 
			VALUES (@viaje_cant_km,@viaje_hora_ini,@viaje_hora_fin,@viaje_chofer,@viaje_auto,@viaje_turno,@viaje_cliente);
		END TRY
		BEGIN CATCH

			SET @codOp = @@ERROR;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al realizar INSERT en la tabla Viaje';

		END CATCH
	END;
END;

GO

--=================================================================================
CREATE PROCEDURE SAPNU_PUAS.sp_rendicion_viajes 
-----------Autor----------------
---------Jonathan---------------

-----Declaracion de Parametros-----
	 @chofer_telefono numeric(18), 
	 @fecha datetime,
	 @turno_codigo int,
	 @porcentaje numeric(5,2),
	 @codOp   int OUT,
	 @resultado  varchar(255) OUT

AS

BEGIN

-----Declaracion de Variables-----
	DECLARE 
	@turno_precio numeric(18),
	@resultado_final numeric(18),
	@cant_kilometros numeric(18),
	@precio_base numeric(18),
	@rendicion_nro numeric(18);
    
	SET NOCOUNT ON;

--SE VERIFICA QUE NO EXISTA UNA RENDICIÓN PARA EL MISMO CHOFER EL MISMO DIA Y TURNO--
		IF(SELECT 
		count(1) 
		from SAPNU_PUAS.Rendicion
		where 
		Rendicion_Chofer = @chofer_telefono
		and CONVERT(date,Rendicion_Fecha) = CONVERT(date,@fecha)
		and Rendicion_Turno = @turno_codigo) > 0

	BEGIN
			SET @codOp = 1;
			SET @resultado = 
			'Ya existe una rendicion registrada en la misma fecha para el chofer ingresado para ese turno';
	END
	
	ELSE

		BEGIN

			--OBTENGO EL VALOR POR KILOMETRO Y EL PRECIO BASE DEL TURNO INGRESADO
			SELECT 
			@turno_precio = turno_valor_kilometro, 
			@precio_base = turno_precio_base
			FROM SAPNU_PUAS.Turno 
			WHERE 
			turno_codigo = @turno_codigo;

			--CALCULO EL VALOR FINAL DE LA RENDICION PARA ESE CHOFER EN ESE TURNO PARA ESE DIA
			SELECT 
			@resultado_final = (sum(Viaje_Cant_Kilometros * @turno_precio + @precio_base) * @porcentaje) 
			FROM SAPNU_PUAS.Viaje 
			WHERE 
			Viaje_Chofer = @chofer_telefono and 
			CONVERT(date,@fecha) = CONVERT(date,Viaje_Fecha_Hora_Inicio) and
			Viaje_Turno = @turno_codigo;

			
			BEGIN TRY
					
					SET @codOp = 0;

					BEGIN TRANSACTION T1
						
						--INSERTO LA RENDICION DE ESE CHOFER PARA ESE TURNO PARA ESE DIA
						INSERT INTO SAPNU_PUAS.Rendicion 
						(Rendicion_Fecha, Rendicion_Importe, Rendicion_Chofer, Rendicion_Turno, Rendicion_Porcentaje)
						VALUES (@fecha, @resultado_final, @chofer_telefono, @turno_codigo, @porcentaje);

						--OBTENGO EL CODIGO DE LA RENDICION RECIEN INSERTADA PARA USARLA EN EL PROXIMO INSERT
						set @rendicion_nro = @@IDENTITY;

						--INSERTO TODOS LOS VIAJES EN VIAJE X RENDICION DESDE LA TABLA DE VIAJES PARA EL CHOFER ESE DIA Y EN ESE TURNO
						INSERT INTO SAPNU_PUAS.Viaje_x_Rendicion
						SELECT Viaje_Codigo, @rendicion_nro from SAPNU_PUAS.Viaje 
						WHERE 
						Viaje_Chofer = @chofer_telefono and 
						CONVERT(date,@fecha) = CONVERT(date,Viaje_Fecha_Hora_Inicio) and
						Viaje_Turno = @turno_codigo;

					--CONFIRMO TRANSACCIONES
					COMMIT TRANSACTION T1

			END TRY
	
			BEGIN CATCH

				SET @codOp = @@ERROR;

				IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al realizar INSERT en Rendicion/Viaje_x_Rendicion';
					--ROLLBACK DE TODAS LAS TRANSACCIONES REALIZADAS PORQUE ALGUNA FALLO
					ROLLBACK TRANSACTION T1

			END CATCH
	
		END
END;
GO

--Store Procedure de facturacion de clientes
CREATE PROCEDURE SAPNU_PUAS.sp_fact_cliente 

	 @fecha_ini datetime, 
	 @fecha_fin datetime,
	 @cliente numeric(18,0),
	 @viajes_fact int,
	 @codOp   int OUT,
	 @resultado  varchar(255) OUT

AS

BEGIN


	DECLARE 
	@importe numeric(18,0),
	@importe_turno numeric(18,0)
    
	SET NOCOUNT ON;

		--Se verifica que exista el cliente recibido por parametro
		IF(SAPNU_PUAS.exist_client(@cliente) = 0)
		BEGIN
			SET @codOp = 1;
			SET @resultado = 'No se encuentra registrado en la base de datos el cliente ingresado.';
		END
		ELSE
		
		--SI CONTROLA QUE NO EXISTA UNA FACTURACION REALIZADA EN EL MISMO MES PARA EL CLIENTE, EN CASO DE HABERLO, SE CANCELA LA FACTURACION.
		IF(EXISTS(SELECT * FROM SAPNU_PUAS.FACTURA
				   WHERE Factura_Cliente = @cliente
				     AND (Factura_Fecha_Inicio BETWEEN @fecha_ini AND @fecha_fin OR
					      Factura_Fecha_Fin    BETWEEN @fecha_ini AND @fecha_fin )))

		BEGIN
			SET @codOp = 2;
			SET @resultado = 'Ya existe una facturacion realizada para el mes ingresado. Verifique las fechas ingresadas.';
		END
	
		ELSE

		BEGIN

			--SE DECLARA CURSOR QUE RECUPERA EL IMPORTE TOTAL POR CADA TURNO
			DECLARE IMPORTES_TURNO_CURSOR CURSOR FOR
			SELECT SUM(B.Turno_Precio_Base)+SUM(A.Viaje_Cant_Kilometros)*b.Turno_Valor_Kilometro as IMPORTE_TURNO
			  FROM SAPNU_PUAS.Viaje A, SAPNU_PUAS.Turno B
            		 WHERE A.Viaje_Cliente = @cliente
               	           AND A.Viaje_Fecha_Hora_Inicio BETWEEN @fecha_ini AND @fecha_fin
                           AND A.Viaje_Fecha_Hora_Fin    BETWEEN @fecha_ini AND @fecha_fin
                           AND B.Turno_Codigo = A.Viaje_Turno
                         GROUP BY A.Viaje_Turno, b.Turno_Valor_Kilometro;

			OPEN IMPORTES_TURNO_CURSOR;

			SET @importe = 0;
			FETCH NEXT FROM IMPORTES_TURNO_CURSOR INTO @importe_turno
			
			--SUMA LOS IMPORTES DE CADA TURNO EN LA VARIABLE @IMPORTE
			WHILE @@FETCH_STATUS = 0  
			BEGIN  
				SET @importe = (@importe  + @importe_turno);
				FETCH NEXT FROM IMPORTES_TURNO_CURSOR INTO @importe_turno
			END;

			CLOSE IMPORTES_TURNO_CURSOR  ;
			DEALLOCATE IMPORTES_TURNO_CURSOR  ;

			BEGIN TRY
					
				SET @codOp = 0;

				INSERT INTO SAPNU_PUAS.Factura
				VALUES (@fecha_ini,@fecha_fin,@importe,SYSDATETIME(),@cliente);

			END TRY
	
			BEGIN CATCH

				SET @codOp = @@ERROR;
				SET @resultado = 'Ocurrio un error al registrar la facturacion en la tabla de facturas.';

			END CATCH
	
		END
END;
GO
