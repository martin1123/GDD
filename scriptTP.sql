USE [GD1C2017]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =======================================================================
-- Author:		Martin Maccio
-- Create date: 11/05/2017
-- Description:	Funcion que verifica que la patente recibida por parametro 
--				no exista en la tabla de Auto
-- =======================================================================
CREATE FUNCTION [dbo].[verificar_patente] 
(

	@patente VARCHAR(10) 
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	SET @Result = (SELECT COUNT(*) 
					FROM dbo.Auto
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
CREATE FUNCTION[dbo].[is_available_hour_range]
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
	                 FROM dbo.turno
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
CREATE PROCEDURE [dbo].[sp_turno_alta]
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
	
    SET @validHora = dbo.is_available_hour_range(@horaInicio,@horaFin, default);

	--Se valida que no haya ningun turno con el que se superpongan los horarios
	IF(@validHora = 0)
	BEGIN
		BEGIN TRY
			SET @codOp = 0;
			INSERT INTO dbo.turno
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
CREATE PROCEDURE [dbo].[sp_turno_modif]
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
	
    SET @validHora = dbo.is_available_hour_range(@horaInicio,@horaFin,@codigo);

	--Se valida que no haya ningun turno con el que se superpongan los horarios
	IF(@validHora = 0)
	BEGIN
		BEGIN TRY
			SET @codOp = 0;
			UPDATE dbo.turno
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
CREATE PROCEDURE sp_auto_alta 

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

	SET @validDuplicado = dbo.verificar_patente(@patente);

	IF(@validDuplicado = 0)
	BEGIN
		BEGIN TRY
			SET @codOp = 0;
			INSERT INTO dbo.Auto
			VALUES(@marca,@modelo,@patente,@licencia,@rodado,@activo,@chofer,@turno);
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
CREATE PROCEDURE sp_auto_modif
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
	SET NOCOUNT ON;

    BEGIN TRY
		SET @codOp = 0;
		UPDATE dbo.Auto
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

GO

CREATE FUNCTION [dbo].[exist_car]
(
	@PATENTE varchar(10)
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM DBO.Auto
		   WHERE Auto_Patente = @PATENTE);

END;

GO

CREATE FUNCTION [dbo].[exist_chofer]
(
	@DNI numeric(18)
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM DBO.Chofer
		   WHERE Chofer_Dni = @DNI);

END;

GO

CREATE FUNCTION [dbo].[exist_turn]
(
	@TURNO int
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM DBO.Turno
		   WHERE Turno_Codigo = @TURNO);

END;

GO

CREATE FUNCTION [dbo].[exist_client]
(
	@CLIENT_TEL numeric(18)
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM DBO.Cliente
		   WHERE Cliente_Telefono = @CLIENT_TEL);

END;

GO

CREATE PROCEDURE [dbo].[sp_viaje_alta] 
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

	IF(dbo.exist_car(@viaje_auto) = 0)
	BEGIN
		SET @codOp = 1;
		SET @resultado = 'No existe un auto con la patente ingresada';
	END
	ELSE IF(dbo.exist_chofer(@viaje_chofer) = 0)
	BEGIN
		SET @codOp = 2;
		SET @resultado = 'El chofer ingresado no se encuentra registrado en el sistema';
	END
	ELSE IF(dbo.exist_turn(@viaje_turno) = 0)
	BEGIN
		SET @codOp = 3;
		SET @resultado = 'No existe el turno ingresado';
	END
	ELSE IF(dbo.exist_client(@viaje_cliente) = 0)
	BEGIN
		SET @codOp = 4;
		SET @resultado = 'El cliente ingresado no se encuentra registrado';
	END;

	IF (@codOp = 0)
	BEGIN
		BEGIN TRY
		--SE VERIFICA QUE NO EXISTA UN VIAJE PARA EL MISMO CLIENTE EN LA MISMA FECHA Y HORA
			IF((SELECT COUNT(*) 
				 FROM DBO.Viaje 
			    WHERE Viaje_Cliente = @viaje_cliente 
			      AND (@viaje_hora_ini BETWEEN Viaje_Fecha_Hora_Inicio AND Viaje_Fecha_Hora_Fin 
			           OR @viaje_hora_FIN BETWEEN Viaje_Fecha_Hora_Inicio AND Viaje_Fecha_Hora_Fin)) > 0)
			BEGIN
				SET @codOp = 5;
				SET @resultado = 'Ya existe un viaje registrado en la misma fecha y hora para el cliente ingresado';
			END
			ELSE
			BEGIN
				INSERT INTO DBO.Viaje 
				VALUES (@viaje_cant_km,@viaje_hora_ini,@viaje_hora_ini,@viaje_hora_fin,@viaje_chofer,@viaje_auto,@viaje_turno,@viaje_cliente);
			END
		END TRY
		BEGIN CATCH

			SET @codOp = @@ERROR;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al realizar INSERT en la tabla Viaje';

		END CATCH
	END;
END;
